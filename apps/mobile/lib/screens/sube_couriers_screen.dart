import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../scan.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Kurye havuzu: haritada canlı konum, altında canlı durum, üzerindeki ve
/// geciken adet, son görülme. Konumlar kuryelerin telefonundan backend'e
/// gider; burada yalnız backend'in verdiği son konum gösterilir.
class SubeCouriersScreen extends ConsumerStatefulWidget {
  const SubeCouriersScreen({super.key});

  @override
  ConsumerState<SubeCouriersScreen> createState() => _SubeCouriersScreenState();
}

class _SubeCouriersScreenState extends ConsumerState<SubeCouriersScreen> {
  Timer? _tick;

  /// Listeden seçilen kurye; harita ona odaklanır.
  String? _focusId;
  int _fitEpoch = 0;

  @override
  void initState() {
    super.initState();
    // Ekran açıkken konumlar yarım dakikada bir yenilenir.
    if (!inWidgetTest) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        // Sekme gizliyken (DgTabStack hepsini canlı tutar) yenileme yok.
        if (ref.read(subeNavProvider).index != SubeNav.couriers) return;
        final branch = ref.read(sessionProvider).branch;
        if (!branch.loading) unawaited(branch.refresh());
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
    final couriers = branch.dashboard?.courierList ?? const [];
    final located = [
      for (final c in couriers)
        if (c.located) c,
    ];
    final focus = located.where((c) => c.id == _focusId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.subeCouriersTitle)),
      body: RefreshIndicator(
        onRefresh: branch.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            SubeStatusBanner(branch: branch),
            if (located.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(Dg.rLg),
                child: MapStrip(
                  height: 260,
                  rounded: false,
                  interactive: true,
                  showBadge: false,
                  fitEpoch: _fitEpoch,
                  couriers: [
                    for (final c in located)
                      FleetCourier(
                        id: c.id,
                        name: c.name,
                        lat: c.latitude!,
                        lng: c.longitude!,
                        status: c.liveStatus == 'ACTIVE' ? 'on' : 'break',
                      ),
                  ],
                  fitTo: [
                    for (final c in focus.isNotEmpty ? focus : located)
                      LatLng(c.latitude!, c.longitude!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                child: Text(
                  l.courierMapCount(located.length, couriers.length),
                  style: Dg.ui(size: 13, color: Dg.ink3),
                ),
              ),
            ] else if (couriers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DgCard(
                  child: Row(
                    children: [
                      DgIcon(LucideIcons.mapPinOff, size: 20, color: Dg.ink3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.courierMapNone,
                          style: Dg.ui(size: 14, color: Dg.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (couriers.isEmpty && !branch.loading)
              DgEmptyState(icon: LucideIcons.users, title: l.emptyCouriers),
            for (final c in couriers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  // Konumu olan kuryeye dokununca harita ona gider.
                  onTap: !c.located
                      ? null
                      : () => setState(() {
                          _focusId = _focusId == c.id ? null : c.id;
                          _fitEpoch++;
                        }),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        name: c.name,
                        size: 40,
                        online: c.liveStatus == 'ACTIVE',
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
                              style: Dg.ui(size: 16, weight: FontWeight.w600),
                            ),
                            Text(
                              [
                                l.holdingCount(c.holdingCount),
                                if (c.overdueCount > 0)
                                  l.overdueCount(c.overdueCount),
                              ].join(' · '),
                              style: Dg.ui(
                                size: 13,
                                color: c.overdueCount > 0 ? Dg.hi : Dg.ink3,
                              ),
                            ),
                            if (c.lastSeenAt != null)
                              Text(
                                l.lastSeenAt(subeClock(c.lastSeenAt!)),
                                style: Dg.ui(size: 13, color: Dg.ink3),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        label: switch (c.liveStatus) {
                          'ACTIVE' => l.liveActive,
                          'BREAK' => l.liveBreak,
                          _ => l.liveOffline,
                        },
                        tone: switch (c.liveStatus) {
                          'ACTIVE' => 'lo',
                          'BREAK' => 'mid',
                          _ => '',
                        },
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
