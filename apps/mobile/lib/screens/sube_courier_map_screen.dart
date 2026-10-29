import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../models.dart';
import '../motion.dart';
import '../scan.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_shipment_detail_screen.dart';
import 'sube_widgets.dart';

typedef _Entry = ({
  BranchCourierLive courier,
  List<MapShipment> shipments,
  CourierKind kind,
});

/// Kurye Haritası (mockup 6): canlı konumlar, durum sekmeleri (Tümü /
/// Dağıtımda / Müsait / Molada / Çevrimdışı). İğneye dokununca altta kurye
/// kartı açılır: ara, üzerindeki gönderiler. Mola vardiya kaydından okunur.
class SubeCourierMapScreen extends ConsumerStatefulWidget {
  const SubeCourierMapScreen({super.key});

  @override
  ConsumerState<SubeCourierMapScreen> createState() =>
      _SubeCourierMapScreenState();
}

class _SubeCourierMapScreenState extends ConsumerState<SubeCourierMapScreen> {
  static const _kinds = [
    null,
    CourierKind.out,
    CourierKind.free,
    CourierKind.onBreak,
    CourierKind.offline,
  ];

  int _tab = 0;
  String? _selectedId;
  int _fitEpoch = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadCourierMap();
    });
    // Ekran açıkken konumlar yarım dakikada bir yenilenir.
    if (!inWidgetTest) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        // Üstüne başka ekran açıldıysa (gönderi detayı) yenileme beklenir.
        if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
        final branch = ref.read(sessionProvider).branch;
        if (!branch.loading) unawaited(branch.loadCourierMap());
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final onBreak = branch.couriersOnBreak;
    final entries = <_Entry>[
      for (final row in branch.courierMap?.couriers ?? const [])
        (
          courier: row.courier,
          shipments: row.shipments,
          kind: courierKind(
            row.courier,
            onBreak: onBreak.contains(row.courier.id),
          ),
        ),
    ];
    final kind = _kinds[_tab];
    final shown = [
      for (final e in entries)
        if (kind == null || e.kind == kind) e,
    ];
    final located = [
      for (final e in shown)
        if (e.courier.located) e,
    ];
    final selected = shown
        .where((e) => e.courier.id == _selectedId)
        .firstOrNull;
    int count(CourierKind? k) =>
        k == null ? entries.length : entries.where((e) => e.kind == k).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.courierMapTitle),
        actions: [
          IconButton(
            tooltip: l.retryNow,
            onPressed: branch.loading ? null : branch.loadCourierMap,
            icon: const Icon(LucideIcons.refreshCw, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: DgPillTabs(
              labels: [
                l.all,
                l.courierOut,
                l.courierFree,
                l.courierOnBreak,
                l.liveOffline,
              ],
              counts: [for (final k in _kinds) count(k)],
              index: _tab,
              onChanged: (i) => setState(() {
                _tab = i;
                _selectedId = null;
                _fitEpoch++;
              }),
            ),
          ),
          if (branch.loading && branch.courierMap == null)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, c) => MapStrip(
                      height: c.maxHeight,
                      rounded: false,
                      interactive: true,
                      showBadge: false,
                      fitEpoch: _fitEpoch,
                      onCourierTap: (id) => setState(
                        () => _selectedId = _selectedId == id ? null : id,
                      ),
                      selectedCourierId: _selectedId,
                      couriers: [
                        for (final e in located)
                          FleetCourier(
                            id: e.courier.id,
                            name: e.courier.name,
                            lat: e.courier.latitude!,
                            lng: e.courier.longitude!,
                            status: courierPinStatus(e.kind),
                          ),
                      ],
                      fitTo: located.isEmpty
                          ? null
                          : [
                              for (final e in located)
                                LatLng(
                                  e.courier.latitude!,
                                  e.courier.longitude!,
                                ),
                            ],
                    ),
                  ),
                ),
                if (branch.error != null && branch.courierMap == null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 12,
                    child: SubeStatusBanner(branch: branch),
                  ),
                // Konumu olmayanlar (çoğu çevrimdışı) haritada görünmez;
                // altta liste olarak durur.
                if (selected == null && shown.length > located.length)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _NoLocationList(
                      entries: [
                        for (final e in shown)
                          if (!e.courier.located) e,
                      ],
                      onTap: (id) => setState(() => _selectedId = id),
                    ),
                  ),
                if (branch.courierMap != null && entries.isEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: DgPanel(
                      child: Text(
                        l.courierMapNone,
                        style: Dg.ui(size: 14, color: Dg.text2),
                      ),
                    ),
                  ),
                if (selected != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Appear(
                      key: ValueKey(selected.courier.id),
                      slide: 0.12,
                      child: _CourierCard(
                        entry: selected,
                        onClose: () => setState(() => _selectedId = null),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoLocationList extends StatelessWidget {
  const _NoLocationList({required this.entries, required this.onTap});

  final List<_Entry> entries;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DgPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l.noLocation} (${entries.length})',
            style: Dg.ui(size: 13, weight: FontWeight.w700, color: Dg.text3),
          ),
          for (final e in entries.take(3))
            InkWell(
              onTap: () => onTap(e.courier.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    InitialsAvatar(name: e.courier.name, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.courier.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 14, weight: FontWeight.w600),
                      ),
                    ),
                    DgStatusPill.of(courierStatus(l, e.kind), dense: true),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seçili kuryenin alt kartı: durum, konum yaşı, eldeki gönderiler; Ara ve
/// gönderi listesi.
class _CourierCard extends StatelessWidget {
  const _CourierCard({required this.entry, required this.onClose});

  final _Entry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = entry.courier;
    final seen = c.lastSeenAt;
    final age = seen == null
        ? null
        : DateTime.now().difference(seen.toLocal()).inMinutes;
    return Material(
      color: Dg.surface1,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(
                  name: c.name,
                  size: 44,
                  online: entry.kind != CourierKind.offline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 17, weight: FontWeight.w700),
                      ),
                      Text(
                        [
                          if (c.code.isNotEmpty) c.code,
                          l.holdingCount(c.holdingCount),
                          if (age != null) l.locationAge(age),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Dg.ui(size: 13, color: Dg.text3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.cancel,
                  onPressed: onClose,
                  icon: Icon(LucideIcons.x, size: 18, color: Dg.text3),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                DgStatusPill.of(courierStatus(l, entry.kind)),
                if (c.overdueCount > 0)
                  DgStatusPill(
                    label: l.overdueCount(c.overdueCount),
                    tone: DgTone.bad,
                    icon: LucideIcons.clockAlert,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DgButton(
                      label: l.call,
                      icon: LucideIcons.phone,
                      tone: DgButtonTone.secondary,
                      onPressed: c.phone == null
                          ? null
                          : () => dialNumber(context, c.phone),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DgButton(
                      label: l.courierDetail,
                      icon: LucideIcons.packageOpen,
                      onPressed: () => _shipmentsSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shipmentsSheet(BuildContext context) {
    final l = context.l10n;
    final list = entry.shipments;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              entry.courier.name,
              style: Dg.ui(size: 18, weight: FontWeight.w700),
            ),
            Text(
              l.mapShipmentsTitle(list.length),
              style: Dg.ui(size: 13, color: Dg.text3),
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Text(l.nothingWaiting, style: Dg.ui(size: 14, color: Dg.text2)),
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DgPanel(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SubeShipmentDetailScreen(
                          row: BranchShipmentRow(
                            shipmentId: s.shipmentId,
                            shipmentNumber: s.shipmentNumber,
                            stage: BranchStage.inDistribution,
                            recipientName: s.recipientName,
                            district: s.district,
                            product: s.product,
                            late: s.overdue,
                            courier: CourierRef(
                              id: entry.courier.id,
                              name: entry.courier.name,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.shipmentNumber,
                              style: Dg.ui(size: 15, weight: FontWeight.w700),
                            ),
                            Text(
                              [
                                s.recipientName,
                                s.district,
                                s.product,
                              ].where((e) => e.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Dg.ui(size: 13, color: Dg.text3),
                            ),
                          ],
                        ),
                      ),
                      if (s.overdue)
                        DgStatusPill(
                          label: l.filterLate,
                          tone: DgTone.bad,
                          dense: true,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
