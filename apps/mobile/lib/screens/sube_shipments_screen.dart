import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_nav.dart';
import 'sube_widgets.dart';

class SubeShipmentsScreen extends ConsumerStatefulWidget {
  const SubeShipmentsScreen({super.key});

  @override
  ConsumerState<SubeShipmentsScreen> createState() =>
      _SubeShipmentsScreenState();
}

class _SubeShipmentsScreenState extends ConsumerState<SubeShipmentsScreen> {
  String _filter = 'all';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final pending = ref.read(subeShipmentFilterProvider);
    if (pending != null) {
      _filter = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(subeShipmentFilterProvider.notifier).state = null;
      });
    }
  }

  bool _matches(BranchShipmentRow r) => switch (_filter) {
    'waiting' => r.stage == BranchStage.awaitingCourier,
    'queue' => r.stage == BranchStage.inQueue,
    'out' => r.stage == BranchStage.inDistribution,
    'booked' => r.booked,
    'priority' => r.highPriority,
    'late' => r.late,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Dashboard kartı / hızlı işlem "şu filtreyle aç" dediyse uygula.
    ref.listen<String?>(subeShipmentFilterProvider, (_, next) {
      if (next == null) return;
      setState(() => _filter = next);
      ref.read(subeShipmentFilterProvider.notifier).state = null;
    });
    final branch = ref.watch(sessionProvider).branch;
    // Ana sayfadaki bir kutudan gelindiyse onun filtresiyle açılır.
    final nav = ref.watch(subeNavProvider);
    if (nav.pendingFilter != null) _filter = nav.takeFilter()!;
    final canOperate = branch.capabilities.operate;
    final chips = <(String, String)>[
      ('all', l.all),
      ('waiting', l.filterWaiting),
      ('queue', l.stageInQueue),
      ('out', l.filterOut),
      ('booked', l.filterBooked),
      ('priority', l.filterPriority),
      ('late', l.filterLate),
    ];
    final rows = [
      for (final r in branch.rows)
        if (_matches(r)) r,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.subeShipmentsTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 32 + MediaQuery.textScalerOf(context).scale(16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c.$2),
                      selected: _filter == c.$1,
                      onSelected: (_) => setState(() => _filter = c.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: branch.refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  branch.picked.isEmpty ? 96 : 16,
                ),
                children: [
                  SubeStatusBanner(branch: branch),
                  if (rows.isEmpty && !branch.loading)
                    DgEmptyState(
                      icon: LucideIcons.package,
                      title: l.emptyShipments,
                    ),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ShipmentCard(
                        row: row,
                        picked: branch.picked.contains(row.shipmentId),
                        onTap: !canOperate || _busy
                            ? null
                            : row.stage == BranchStage.awaitingCourier
                            ? () => branch.togglePick(row.shipmentId)
                            : row.stage == BranchStage.incoming
                            ? null
                            : () => _rowActions(branch, row),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (branch.picked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: DgButton(
                label: '${l.assignToCourier} · ${branch.picked.length}',
                icon: LucideIcons.userPlus,
                busy: _busy,
                onPressed: () => _assign(branch),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _guard(Future<String?> Function() run, String done) async {
    setState(() => _busy = true);
    final error = await run();
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? done);
  }

  Future<void> _assign(BranchWorkspace branch) async {
    final l = context.l10n;
    final first = branch.pickedRows.firstOrNull;
    if (first == null) return;
    final courier = await _pickCourier(
      title: l.selectedCount(branch.picked.length),
      load: () async {
        final o = await branch.courierOptions(first.shipmentId);
        return (o.couriers, o.ready ? null : l.dispatchNotReady);
      },
    );
    if (courier == null) return;
    await _guard(() => branch.assignPicked(courier), l.handoverCreated);
  }

  Future<void> _rowActions(
    BranchWorkspace branch,
    BranchShipmentRow row,
  ) async {
    final l = context.l10n;
    final inQueue = row.stage == BranchStage.inQueue;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      builder: (ctx) {
        Widget actionRow({
          required IconData icon,
          required String label,
          required Color color,
          required String value,
        }) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Material(
            color: Dg.elev,
            borderRadius: BorderRadius.circular(Dg.radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(Dg.radius),
              onTap: () => Navigator.pop(ctx, value),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: Dg.dark ? 0.18 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: DgIcon(icon, size: 19, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: Dg.ui(size: 16, weight: FontWeight.w600),
                      ),
                    ),
                    DgIcon(LucideIcons.chevronRight, size: 18, color: Dg.ink3),
                  ],
                ),
              ),
            ),
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kime gittiği ve kimde olduğu: önce bunlar okunur.
                Text(
                  row.recipientName,
                  style: Dg.ui(size: 20, weight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    row.shipmentNumber,
                    if (row.district.isNotEmpty) row.district,
                  ].join(' · '),
                  style: Dg.ui(size: 14, color: Dg.ink3),
                ),
                if (row.courierName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InitialsAvatar(name: row.courierName, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          row.courierName,
                          style: Dg.ui(size: 15, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                actionRow(
                  icon: LucideIcons.repeat,
                  label: l.reassign,
                  color: Dg.plum,
                  value: 'change',
                ),
                if (inQueue)
                  actionRow(
                    icon: LucideIcons.circleX,
                    label: l.cancelHandover,
                    color: Dg.bad,
                    value: 'cancel',
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    if (action == 'cancel') {
      final reason = await _pickReason(branch);
      if (reason == null) return;
      await _guard(
        () => branch.cancelHandover(row, reason.code),
        l.handoverCancelled,
      );
      return;
    }
    final courier = await _pickCourier(
      title: row.shipmentNumber,
      load: () async {
        if (inQueue) {
          final o = await branch.courierOptions(row.shipmentId);
          return (o.couriers, null);
        }
        return (await branch.reassignOptions(row.shipmentId), null);
      },
    );
    if (courier == null || !mounted) return;
    // Dağıtımdaki gönderide devir denetim kaydına not düşer.
    final note = inQueue ? null : await _askNote();
    if (!inQueue && note == null) return;
    await _guard(
      () => branch.changeCourier(row, courier, note: note),
      l.courierChanged,
    );
  }

  Future<CourierOption?> _pickCourier({
    required String title,
    required Future<(List<CourierOption>, String?)> Function() load,
  }) {
    final l = context.l10n;
    final future = load();
    return showModalBottomSheet<CourierOption>(
      context: context,
      backgroundColor: Dg.surface,
      builder: (ctx) => FutureBuilder(
        future: future,
        builder: (ctx, snap) {
          final couriers = snap.data?.$1 ?? const <CourierOption>[];
          final warning = snap.data?.$2;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            shrinkWrap: true,
            children: [
              Text(
                l.pickCourier,
                style: Dg.ui(size: 17, weight: FontWeight.w700),
              ),
              Text(title, style: Dg.ui(size: 13, color: Dg.ink3)),
              const SizedBox(height: 12),
              if (snap.connectionState != ConnectionState.done)
                const Center(child: CircularProgressIndicator())
              else if (snap.hasError)
                Text(
                  BranchWorkspace.describeError(snap.error!),
                  style: Dg.ui(size: 14, color: Dg.hi),
                )
              else if (couriers.isEmpty)
                Text(
                  l.noCouriersToPick,
                  style: Dg.ui(size: 14, color: Dg.ink2),
                ),
              if (warning != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(warning, style: Dg.ui(size: 13, color: Dg.mid)),
                ),
              for (final c in couriers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InitialsAvatar(name: c.name, size: 36),
                  title: Text(c.name),
                  subtitle: Text(c.code),
                  trailing: c.eligible
                      ? null
                      : StatusChip(label: l.outOfRegion, tone: 'mid'),
                  onTap: () => Navigator.pop(ctx, c),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<ReasonOption?> _pickReason(BranchWorkspace branch) {
    final l = context.l10n;
    final future = branch.cancelReasons();
    return showModalBottomSheet<ReasonOption>(
      context: context,
      backgroundColor: Dg.surface,
      builder: (ctx) => FutureBuilder(
        future: future,
        builder: (ctx, snap) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          shrinkWrap: true,
          children: [
            Text(l.pickReason, style: Dg.ui(size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (snap.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (snap.hasError)
              Text(
                BranchWorkspace.describeError(snap.error!),
                style: Dg.ui(size: 14, color: Dg.hi),
              ),
            for (final r in snap.data ?? const <ReasonOption>[])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.name),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
  }

  /// İptalde null, onayda (boş olabilir) not döner.
  Future<String?> _askNote() async {
    final l = context.l10n;
    final controller = TextEditingController();
    final note = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Dg.surface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reassign, style: Dg.ui(size: 17, weight: FontWeight.w700)),
            TextField(
              controller: controller,
              maxLength: 500,
              decoration: InputDecoration(hintText: l.noteOptional),
            ),
            const SizedBox(height: 12),
            DgButton(
              label: l.reassign,
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return note;
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({required this.row, required this.picked, this.onTap});

  final BranchShipmentRow row;
  final bool picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, tone) = switch (row.stage) {
      BranchStage.incoming => (l.stageIncoming, 'mid'),
      BranchStage.awaitingCourier => (l.stageAwaiting, 'mid'),
      BranchStage.inQueue => (l.stageInQueue, 'mid'),
      BranchStage.inDistribution => (l.filterOut, 'lime'),
    };
    return DgCard(
      onTap: onTap,
      child: Row(
        children: [
          if (row.stage == BranchStage.awaitingCourier) ...[
            Icon(
              picked ? LucideIcons.squareCheck : LucideIcons.square,
              size: 20,
              color: Dg.ink2,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Önce kime gittiği; gönderi no ve bölge altta, küçük.
                Text(
                  row.recipientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 16, weight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.shipmentNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 13, color: Dg.ink3),
                      ),
                    ),
                    if (row.district.isNotEmpty)
                      Flexible(
                        child: Text(
                          ' · ${row.district}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Dg.ui(size: 13, color: Dg.ink3),
                        ),
                      ),
                  ],
                ),
                if (row.courierName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        DgIcon(LucideIcons.bike, size: 13, color: Dg.ink3),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            row.courierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Dg.ui(size: 13, color: Dg.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Etiket kendi genişliğini alır; ad ve numara kalan yere yayılır.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.42,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(label: label, tone: tone),
                if (row.late || row.highPriority) ...[
                  const SizedBox(height: 4),
                  StatusChip(
                    label: row.late ? l.filterLate : l.filterPriority,
                    tone: 'hi',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
