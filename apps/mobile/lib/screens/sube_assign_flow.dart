import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Atama türü: zimmet bekleyene yeni zimmet, kabul bekleyende zimmeti
/// çevirme (toplu), dağıtımdakinde devir (tek gönderi, denetim notlu).
enum AssignMode { assign, change, reassign }

/// Kurye Atama (mockup 4): seçilen gönderiler için kurye listesi ya da
/// haritası; seçilen kuryeye tek dokunuşla atanır. Kurye listesi sunucunun
/// atanabilir dediği kuryelerdir; canlı durum ve öneri bilgisi üstüne eklenir.
class SubeAssignFlow extends ConsumerStatefulWidget {
  const SubeAssignFlow({super.key, required this.mode, required this.rows});

  final AssignMode mode;
  final List<BranchShipmentRow> rows;

  @override
  ConsumerState<SubeAssignFlow> createState() => _SubeAssignFlowState();
}

class _SubeAssignFlowState extends ConsumerState<SubeAssignFlow> {
  late final Future<({List<CourierOption> couriers, bool ready})> _options;
  late final Future<ShipmentDetail?> _detail;
  int _tab = 0;
  String? _selectedId;
  bool _busy = false;

  BranchWorkspace get _branch => ref.read(sessionProvider).branch;

  @override
  void initState() {
    super.initState();
    final first = widget.rows.first.shipmentId;
    _options = widget.mode == AssignMode.reassign
        ? _branch.reassignOptions(first).then((c) => (couriers: c, ready: true))
        : _branch
              .courierOptions(first)
              .then((o) => (couriers: o.couriers, ready: o.ready));
    // Öneriler (bölge uyumu, aktif iş, varış) yalnız ek bilgidir; gelmezse
    // liste yine çalışır.
    _detail = _branch
        .shipmentDetail(first)
        .then<ShipmentDetail?>((d) => d)
        .catchError((Object _) => null);
  }

  Future<void> _submit(CourierOption courier) async {
    final l = context.l10n;
    final branch = _branch;
    final ids = [for (final r in widget.rows) r.shipmentId];
    String? note;
    if (widget.mode == AssignMode.reassign) {
      note = await _askNote();
      if (note == null || !mounted) return;
    }
    setState(() => _busy = true);
    final error = switch (widget.mode) {
      AssignMode.assign => await branch.assignShipments(ids, courier),
      AssignMode.change => await branch.changeShipments(ids, courier),
      AssignMode.reassign => await branch.changeCourier(
        widget.rows.first,
        courier,
        note: note,
      ),
    };
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      subeSnack(context, error);
      return;
    }
    subeSnack(
      context,
      widget.mode == AssignMode.assign ? l.handoverCreated : l.courierChanged,
    );
    Navigator.of(context).pop(true);
  }

  /// Dağıtımdaki gönderinin devrinde denetim notu. Vazgeçilirse null.
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
            DgGradientButton(
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = widget.rows.length;
    final live = {
      for (final c
          in ref.watch(sessionProvider).branch.dashboard?.courierList ??
              const <BranchCourierLive>[])
        c.id: c,
    };
    final onBreak = _branch.couriersOnBreak;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == AssignMode.assign ? l.assignTitle : l.changeTitle,
        ),
      ),
      body: FutureBuilder(
        future: _options,
        builder: (context, snap) {
          final couriers = snap.data?.couriers ?? const <CourierOption>[];
          final selected = couriers
              .where((c) => c.id == _selectedId)
              .firstOrNull;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _ShipmentsSummary(rows: widget.rows),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DgPillTabs(
                  labels: [l.tabList, l.tabMap],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              if (snap.data?.ready == false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    l.dispatchNotReady,
                    style: Dg.ui(size: 13, color: Dg.warn),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: snap.connectionState != ConnectionState.done
                    ? const _ListSkeleton()
                    : snap.hasError
                    ? _ErrorText(BranchWorkspace.describeError(snap.error!))
                    : couriers.isEmpty
                    ? DgEmptyState(
                        icon: LucideIcons.users,
                        title: l.noCouriersToPick,
                      )
                    : FutureBuilder<ShipmentDetail?>(
                        future: _detail,
                        builder: (context, detailSnap) {
                          final hints = {
                            for (final s
                                in detailSnap.data?.suggestions ??
                                    const <CourierSuggestion>[])
                              s.id: s,
                          };
                          return DgTabStack(
                            index: _tab,
                            children: [
                              _CourierList(
                                couriers: couriers,
                                live: live,
                                hints: hints,
                                onBreak: onBreak,
                                selectedId: _selectedId,
                                onPick: (id) =>
                                    setState(() => _selectedId = id),
                              ),
                              _CourierMapPick(
                                couriers: couriers,
                                live: live,
                                onBreak: onBreak,
                                selectedId: _selectedId,
                                onPick: (id) =>
                                    setState(() => _selectedId = id),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: DgGradientButton(
                    key: const Key('assign-confirm'),
                    label: selected == null
                        ? l.pickCourierFirst
                        : widget.mode == AssignMode.assign
                        ? l.assignConfirm(n)
                        : l.changeConfirm(n),
                    icon: LucideIcons.userCheck,
                    busy: _busy,
                    onPressed: selected == null || _busy
                        ? null
                        : () => _submit(selected),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Seçilen gönderilerin özeti: adet ve ilk birkaç numara.
class _ShipmentsSummary extends StatelessWidget {
  const _ShipmentsSummary({required this.rows});

  final List<BranchShipmentRow> rows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final numbers = rows.take(3).map((r) => r.shipmentNumber).join(', ');
    return DgPanel(
      child: Row(
        children: [
          const DgIconBadge(icon: LucideIcons.package, tone: DgTone.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.selectedShipments(rows.length),
                  style: Dg.ui(size: 15, weight: FontWeight.w700),
                ),
                Text(
                  rows.length > 3 ? '$numbers …' : numbers,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 13, color: Dg.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierList extends StatelessWidget {
  const _CourierList({
    required this.couriers,
    required this.live,
    required this.hints,
    required this.onBreak,
    required this.selectedId,
    required this.onPick,
  });

  final List<CourierOption> couriers;
  final Map<String, BranchCourierLive> live;
  final Map<String, CourierSuggestion> hints;
  final Set<String> onBreak;
  final String? selectedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    // Önerilenler (bölgesinde, sonra yakın) üstte; sunucu sırası korunur.
    int rank(CourierOption c) => switch (hints[c.id]?.regionFit) {
      'MATCH' => 0,
      'PARTIAL' => 1,
      _ => c.eligible ? 2 : 3,
    };
    final sorted = [...couriers]..sort((a, b) => rank(a).compareTo(rank(b)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final c = sorted[i];
        final tile = Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AssignCourierTile(
            option: c,
            live: live[c.id],
            hint: hints[c.id],
            onBreak: onBreak.contains(c.id),
            selected: c.id == selectedId,
            onTap: () => onPick(c.id),
          ),
        );
        return i < 6 ? StaggerIn(index: i, child: tile) : tile;
      },
    );
  }
}

/// Kurye satırı: baş harf, ad + kod, canlı durum hapı, öneri bilgisi
/// (bölge uyumu, aktif iş, varış) ve seçim işareti.
class AssignCourierTile extends StatelessWidget {
  const AssignCourierTile({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
    this.live,
    this.hint,
    this.onBreak = false,
  });

  final CourierOption option;
  final BranchCourierLive? live;
  final CourierSuggestion? hint;
  final bool onBreak;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kind = live == null ? null : courierKind(live!, onBreak: onBreak);
    final fit = hint?.regionFit ?? (option.eligible ? null : 'NONE');
    final facts = [
      if (hint != null) l.activeJobs(hint!.activeJobs),
      if (hint == null && live != null) l.holdingCount(live!.holdingCount),
      if (hint?.etaMinutes != null) l.etaMinutes(hint!.etaMinutes!),
    ];
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: DgMotion.quick,
        curve: DgMotion.enter,
        // Yalnız seçili kurye halkalı; diğerleri çerçevesiz kart.
        decoration: Dg.card(radius: 16).copyWith(
          border: selected
              ? Border.all(color: Dg.brandTurquoise, width: 2)
              : null,
        ),
        child: Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InitialsAvatar(
                  name: option.name,
                  size: 42,
                  online: kind == CourierKind.out || kind == CourierKind.free,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 16, weight: FontWeight.w600),
                      ),
                      if (facts.isNotEmpty || option.code.isNotEmpty)
                        Text(
                          [
                            if (option.code.isNotEmpty) option.code,
                            ...facts,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Dg.ui(size: 13, color: Dg.text3),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (kind != null)
                            DgStatusPill.of(
                              courierStatus(l, kind),
                              dense: true,
                            ),
                          if (fit != null)
                            DgStatusPill(
                              label: l.regionFit(fit),
                              tone: switch (fit) {
                                'MATCH' => DgTone.ok,
                                'PARTIAL' => DgTone.info,
                                _ => DgTone.warn,
                              },
                              icon: LucideIcons.mapPin,
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DgMotion.quick,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Dg.brandTurquoise : Dg.stroke,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        duration: DgMotion.quick,
        curve: DgMotion.springy,
        scale: selected ? 1 : 0,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Dg.brandTurquoise,
          ),
        ),
      ),
    );
  }
}

/// Harita sekmesi: konumu bilinen atanabilir kuryeler; iğneye dokununca
/// seçilir, altta seçili kuryenin kartı.
class _CourierMapPick extends StatelessWidget {
  const _CourierMapPick({
    required this.couriers,
    required this.live,
    required this.onBreak,
    required this.selectedId,
    required this.onPick,
  });

  final List<CourierOption> couriers;
  final Map<String, BranchCourierLive> live;
  final Set<String> onBreak;
  final String? selectedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final located = [
      for (final c in couriers)
        if (live[c.id]?.located == true) (option: c, live: live[c.id]!),
    ];
    if (located.isEmpty) {
      return DgEmptyState(icon: LucideIcons.mapPinOff, title: l.courierMapNone);
    }
    final selected = couriers.where((c) => c.id == selectedId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, c) => MapStrip(
                  height: c.maxHeight,
                  rounded: false,
                  interactive: true,
                  showBadge: false,
                  onCourierTap: onPick,
                  selectedCourierId: selectedId,
                  couriers: [
                    for (final x in located)
                      FleetCourier(
                        id: x.option.id,
                        name: x.option.name,
                        lat: x.live.latitude!,
                        lng: x.live.longitude!,
                        status: courierPinStatus(
                          courierKind(
                            x.live,
                            onBreak: onBreak.contains(x.option.id),
                          ),
                        ),
                      ),
                  ],
                  fitTo: [
                    for (final x in located)
                      LatLng(x.live.latitude!, x.live.longitude!),
                  ],
                ),
              ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Appear(
              key: ValueKey(selected.id),
              child: AssignCourierTile(
                option: selected,
                live: live[selected.id],
                onBreak: onBreak.contains(selected.id),
                selected: true,
                onTap: () {},
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: DgSkeleton(height: 76, radius: 16),
          ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Dg.ui(size: 14, color: Dg.bad),
      ),
    );
  }
}
