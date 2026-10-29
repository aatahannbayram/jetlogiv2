import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_features.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_assign_flow.dart';
import 'sube_header.dart';
import 'sube_print.dart';
import 'sube_shipment_detail_screen.dart';
import 'sube_widgets.dart';

/// Gönderiler (mockup 2): arama, süzgeç çipleri (Tarih / İlçe / Durum /
/// Kurye), durum sekmeleri ve durum haplı liste. Satıra dokunmak detayı
/// açar; kutucuk (ya da uzun basış) seçer, seçim varken "Toplu İşlemler"
/// çubuğu aşağıdan gelir.
class SubeShipmentsScreen extends ConsumerStatefulWidget {
  const SubeShipmentsScreen({super.key});

  @override
  ConsumerState<SubeShipmentsScreen> createState() =>
      _SubeShipmentsScreenState();
}

class _SubeShipmentsScreenState extends ConsumerState<SubeShipmentsScreen> {
  static const _tabs = ['all', 'waiting', 'queue', 'out', 'late'];

  int _tab = 0;
  String _query = '';
  String? _district;
  String? _courier;

  /// Durum süzgeci: randevulu / öncelikli.
  String? _flag;

  bool _inTab(BranchShipmentRow r, String tab) => switch (tab) {
    'waiting' => r.stage == BranchStage.awaitingCourier,
    'queue' => r.stage == BranchStage.inQueue,
    'out' => r.stage == BranchStage.inDistribution,
    'late' => r.late,
    _ => true,
  };

  bool _matches(BranchShipmentRow r) {
    if (!_inTab(r, _tabs[_tab])) return false;
    if (_district != null && r.district != _district) return false;
    if (_courier != null && r.courierName != _courier) return false;
    if (_flag == 'booked' && !r.booked) return false;
    if (_flag == 'priority' && !r.highPriority) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      r.shipmentNumber,
      r.recipientName,
      r.district,
      r.addressLine,
      r.courierName,
    ].any((v) => v.toLowerCase().contains(q));
  }

  /// Ana sayfadaki bir kutudan gelindiyse onun süzgeciyle açılır.
  void _takeFilter(SubeNav nav) {
    final f = nav.pendingFilter;
    if (f == null) return;
    nav.takeFilter();
    _flag = null;
    if (f == 'booked' || f == 'priority') {
      _tab = 0;
      _flag = f;
    } else {
      _tab = _tabs.indexOf(f).clamp(0, _tabs.length - 1);
    }
  }

  void _open(BranchShipmentRow row) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SubeShipmentDetailScreen(row: row)),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    _takeFilter(ref.watch(subeNavProvider));
    final all = branch.rows;
    final rows = [
      for (final r in all)
        if (_matches(r)) r,
    ];
    final counts = [
      for (final t in _tabs) all.where((r) => _inTab(r, t)).length,
    ];
    final districts = {
      for (final r in all)
        if (r.district.isNotEmpty) r.district,
    }.toList()..sort();
    final couriers = {
      for (final r in all)
        if (r.courierName.isNotEmpty) r.courierName,
    }.toList()..sort();
    final selecting = branch.picked.isNotEmpty;
    final canOperate = branch.capabilities.operate;

    return Scaffold(
      appBar: const SubeHeaderBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: DgPageTitle(
                  l.subeShipmentsTitle,
                  subtitle: l.shipmentsCount(rows.length),
                  trailing: !canOperate || rows.isEmpty
                      ? null
                      : TextButton(
                          onPressed: selecting
                              ? branch.clearPicked
                              : () => branch.pickAll(rows),
                          child: Text(
                            selecting ? l.clearSelection : l.selectAll,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DgSearchField(
                  hint: l.searchShipmentsHint,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36 + MediaQuery.textScalerOf(context).scale(4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    DgFilterChip(
                      label: l.filterDate,
                      icon: LucideIcons.calendar,
                      onTap: _datePending,
                    ),
                    const SizedBox(width: 8),
                    DgFilterChip(
                      label: l.filterDistrict,
                      value: _district,
                      icon: LucideIcons.mapPin,
                      onTap: () async {
                        final r = await showDgPicker<String>(
                          context,
                          title: l.filterDistrict,
                          allLabel: l.all,
                          options: [for (final d in districts) (d, d)],
                          selected: _district,
                        );
                        if (r.picked && mounted) {
                          setState(() => _district = r.value);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    DgFilterChip(
                      label: l.filterStatus,
                      value: switch (_flag) {
                        'booked' => l.filterBooked,
                        'priority' => l.filterPriority,
                        _ => null,
                      },
                      icon: LucideIcons.slidersHorizontal,
                      onTap: () async {
                        final r = await showDgPicker<String>(
                          context,
                          title: l.filterStatus,
                          allLabel: l.all,
                          options: [
                            ('booked', l.filterBooked),
                            ('priority', l.filterPriority),
                          ],
                          selected: _flag,
                        );
                        if (r.picked && mounted) {
                          setState(() => _flag = r.value);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    DgFilterChip(
                      label: l.filterCourier,
                      value: _courier,
                      icon: LucideIcons.bike,
                      onTap: () async {
                        final r = await showDgPicker<String>(
                          context,
                          title: l.filterCourier,
                          allLabel: l.all,
                          options: [for (final c in couriers) (c, c)],
                          selected: _courier,
                        );
                        if (r.picked && mounted) {
                          setState(() => _courier = r.value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DgPillTabs(
                  labels: [
                    l.all,
                    l.filterWaiting,
                    l.filterQueue,
                    l.filterOut,
                    l.filterLate,
                  ],
                  counts: counts,
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: branch.refresh,
                  child: rows.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          children: [
                            SubeStatusBanner(branch: branch),
                            if (branch.loading && branch.board == null)
                              for (var i = 0; i < 4; i++)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: DgSkeleton(height: 92, radius: 16),
                                )
                            else
                              DgEmptyState(
                                icon: LucideIcons.package,
                                title: l.emptyShipments,
                              ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          itemCount: rows.length + 1,
                          itemBuilder: (context, i) {
                            if (i == 0) return SubeStatusBanner(branch: branch);
                            final row = rows[i - 1];
                            final pickable =
                                canOperate && BranchWorkspace.pickable(row);
                            final picked = branch.picked.contains(
                              row.shipmentId,
                            );
                            final tile = Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ShipmentTile(
                                row: row,
                                picked: picked,
                                onPick: pickable
                                    ? () => branch.togglePick(row.shipmentId)
                                    : null,
                                onTap: selecting && pickable
                                    ? () => branch.togglePick(row.shipmentId)
                                    : () => _open(row),
                              ),
                            );
                            return i <= 6
                                ? StaggerIn(index: i - 1, child: tile)
                                : tile;
                          },
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: DgBulkBar(
              count: branch.picked.length,
              label: l.bulkActions,
              onPressed: () => _bulk(branch),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _datePending() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Dg.surface,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DgPendingBackend(what: context.l10n.dateFilterPending),
      ),
    ),
  );

  Future<void> _bulk(BranchWorkspace branch) async {
    final l = context.l10n;
    final picked = branch.pickedRows;
    final waiting = [
      for (final r in picked)
        if (r.stage == BranchStage.awaitingCourier) r,
    ];
    final queue = [
      for (final r in picked)
        if (r.stage == BranchStage.inQueue) r,
    ];
    final inField = picked.any((r) => r.stage == BranchStage.inDistribution);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  '${l.bulkActions} · ${l.selectedCount(picked.length)}',
                  style: Dg.ui(size: 17, weight: FontWeight.w700),
                ),
              ),
              _BulkOption(
                key: const Key('bulk-assign'),
                icon: LucideIcons.userPlus,
                tone: DgTone.info,
                label: l.bulkAssign,
                hint: l.bulkAssignHint(waiting.length),
                onTap: waiting.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, 'assign'),
              ),
              _BulkOption(
                key: const Key('bulk-change'),
                icon: LucideIcons.repeat,
                tone: DgTone.accent,
                label: l.bulkChange,
                hint: [
                  l.bulkChangeHint(queue.length),
                  if (inField) l.bulkChangeFieldNote,
                ].join('\n'),
                onTap: queue.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, 'change'),
              ),
              _BulkOption(
                key: const Key('bulk-print'),
                icon: LucideIcons.printer,
                tone: DgTone.neutral,
                label: l.bulkPrint,
                hint: l.bulkPrintHint(picked.length),
                onTap: () => Navigator.pop(ctx, 'print'),
              ),
              _BulkOption(
                icon: LucideIcons.link2,
                tone: DgTone.neutral,
                label: l.bulkProductMatch,
                hint: l.pendingBackendTitle,
                onTap: BranchFeatures.productMatch
                    ? () => Navigator.pop(ctx, 'match')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'assign':
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                SubeAssignFlow(mode: AssignMode.assign, rows: waiting),
          ),
        );
      case 'change':
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                SubeAssignFlow(mode: AssignMode.change, rows: queue),
          ),
        );
      case 'print':
        final printed = await printShipmentLabels(context, branch, [
          for (final r in picked) r.shipmentId,
        ]);
        if (printed != null) branch.clearPicked();
    }
  }
}

class _BulkOption extends StatelessWidget {
  const _BulkOption({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final DgTone tone;
  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: DgPanel(
          onTap: onTap,
          child: Row(
            children: [
              DgIconBadge(icon: icon, tone: tone, size: 40, soft: !enabled),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Dg.ui(size: 16, weight: FontWeight.w600),
                    ),
                    Text(hint, style: Dg.typeCaption()),
                  ],
                ),
              ),
              if (enabled)
                Icon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gönderi satırı: seçim kutusu, numara (detaya uçar), durum hapı, alıcı,
/// adres, kurye ve randevu.
class ShipmentTile extends StatelessWidget {
  const ShipmentTile({
    super.key,
    required this.row,
    required this.picked,
    required this.onTap,
    this.onPick,
  });

  final BranchShipmentRow row;
  final bool picked;
  final VoidCallback onTap;

  /// Seçilemeyen satırda null (kutucuk görünmez).
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final caption = Dg.ui(size: 13, color: Dg.text3);
    final place = [
      row.district,
      row.addressLine,
    ].where((e) => e.isNotEmpty).join(' · ');
    return AnimatedContainer(
      duration: DgMotion.quick,
      // Seçili satır çerçeve yerine mavi tonla ayrışır.
      decoration: Dg.card(
        radius: 16,
        color: picked
            ? Color.alphaBlend(Dg.action.withValues(alpha: 0.18), Dg.surface1)
            : null,
      ),
      child: Pressable(
        onTap: onTap,
        onLongPress: onPick,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onPick != null)
                Semantics(
                  checked: picked,
                  label: row.shipmentNumber,
                  child: GestureDetector(
                    key: Key('pick-${row.shipmentId}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onPick,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 10, 8),
                      child: DgSelectBox(selected: picked),
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShipmentNumberHero(
                            row: row,
                            style: Dg.ui(size: 15, weight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DgStatusPill.of(shipmentStatus(l, row), dense: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.recipientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Dg.ui(size: 15, weight: FontWeight.w600),
                    ),
                    if (place.isNotEmpty)
                      Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: caption,
                      ),
                    if (row.courierName.isNotEmpty ||
                        row.booked ||
                        row.late ||
                        row.highPriority) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (row.courierName.isNotEmpty)
                            _Fact(
                              icon: LucideIcons.bike,
                              text: row.courierName,
                            ),
                          if (row.booked)
                            _Fact(
                              icon: LucideIcons.calendarClock,
                              text: [
                                subeClock(row.windowStart!),
                                if (row.windowEnd != null)
                                  subeClock(row.windowEnd!),
                              ].join('–'),
                            ),
                          if (row.late)
                            DgStatusPill(
                              label: l.filterLate,
                              tone: DgTone.bad,
                              dense: true,
                            ),
                          if (row.highPriority)
                            DgStatusPill(
                              label: l.filterPriority,
                              tone: DgTone.warn,
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Dg.text3),
        const SizedBox(width: 4),
        Text(text, style: Dg.ui(size: 13, color: Dg.text2)),
      ],
    );
  }
}
