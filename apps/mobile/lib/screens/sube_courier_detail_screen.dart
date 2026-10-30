import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/branch_models.dart';
import '../api/branch_proposed_models.dart';
import '../branch_features.dart';
import '../branch_workspace.dart';
import '../brand.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../models.dart' show formatTrPhone;
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

String _date(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year}';
}

/// Kurye Detayı (mockup 15–18): üst kart (ad, kod, durum, ara) ve dört
/// sekme: Genel (iletişim, araç, bölge, canlı durum, performans), Kart (QR),
/// Evraklar (belge kalemleri, onaylar), Cihaz. Plaka, cihaz ve kart
/// yenile / iptal önerilen uçlara bağlı (docs/15 §8–10).
class SubeCourierDetailScreen extends ConsumerStatefulWidget {
  const SubeCourierDetailScreen({super.key, required this.courier});

  final BranchCourier courier;

  @override
  ConsumerState<SubeCourierDetailScreen> createState() =>
      _SubeCourierDetailScreenState();
}

class _SubeCourierDetailScreenState
    extends ConsumerState<SubeCourierDetailScreen> {
  int _tab = 0;
  Future<PartnerCard>? _card;

  BranchWorkspace get _branch => ref.read(sessionProvider).branch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final branch = _branch;
      if (branch.compliance == null) branch.loadCompliance();
      if (branch.performance == null) branch.loadPerformance('7d');
      if (branch.shiftDay == null) branch.loadDashExtras();
      branch.loadCourierProfile(widget.courier.id);
    });
  }

  Future<void> _renew() async {
    final l = context.l10n;
    final next = _branch.renewCourierCard(widget.courier.id);
    setState(() => _card = next);
    try {
      await next;
      if (mounted) subeSnack(context, l.cardRenewed);
    } catch (_) {
      // Hata kart sekmesinde gösterilir.
    }
  }

  Future<void> _revoke() async {
    final l = context.l10n;
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l.cardRevokeTitle,
                style: Dg.ui(size: 17, weight: FontWeight.w700),
              ),
            ),
            for (final code in const ['LOST', 'DAMAGED', 'LEFT', 'OTHER'])
              ListTile(
                key: Key('revoke-$code'),
                title: Text(l.cardRevokeReason(code)),
                onTap: () => Navigator.pop(ctx, code),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final error = await _branch.revokeCourierCard(widget.courier.id, reason);
    if (!mounted) return;
    subeSnack(context, error ?? l.cardRevoked);
    if (error == null) {
      setState(() {
        _tab = 0;
        _card = null;
      });
    }
  }

  void _select(int i) => setState(() {
    _tab = i;
    // Kart ilk açılışta üretilir; aynı gün aynı kart döner.
    if (i == 1) _card ??= _branch.courierCard(widget.courier.id);
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final c = widget.courier;
    final live = (branch.dashboard?.courierList ?? const <BranchCourierLive>[])
        .where((x) => x.id == c.id)
        .firstOrNull;
    final docs = (branch.compliance ?? const <CourierCompliance>[])
        .where((x) => x.id == c.id)
        .firstOrNull;
    final shift = (branch.shiftDay?.couriers ?? const <ShiftCourierRow>[])
        .where((x) => x.courierId == c.id)
        .firstOrNull;
    final perf = branch.performance;
    final mine = (perf?.couriers ?? const <CourierPerformance>[])
        .where((x) => x.courierId == c.id)
        .firstOrNull;
    final kind = live == null || !c.active
        ? null
        : courierKind(live, onBreak: shift?.onBreak ?? false);
    final profile = branch.courierProfiles[c.id];
    final cardActions =
        branch.proposed(BranchFeatures.cardRenew) &&
        branch.capabilities.operate;

    return Scaffold(
      appBar: AppBar(title: Text(l.courierDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Header(courier: c, kind: kind),
          const SizedBox(height: 12),
          DgPillTabs(
            labels: [l.tabGeneral, l.tabCard, l.tabDocs, l.tabDevice],
            index: _tab,
            onChanged: _select,
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: DgMotion.standard,
            switchInCurve: DgMotion.enter,
            switchOutCurve: DgMotion.exit,
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                0 => _General(
                  courier: c,
                  live: live,
                  kind: kind,
                  shift: shift,
                  perf: mine,
                  range: perf?.range,
                  profile: profile,
                ),
                1 => _CardTab(
                  future: _card,
                  courier: c,
                  ready: branch.proposed(BranchFeatures.cardRenew),
                  onRenew: cardActions ? _renew : null,
                  onRevoke: cardActions ? _revoke : null,
                ),
                2 => _DocsTab(
                  docs: docs,
                  loading: branch.loading && branch.compliance == null,
                ),
                _ =>
                  branch.proposed(BranchFeatures.courierDevice)
                      ? _DeviceTab(
                          profile: profile,
                          loading: branch.loading && profile == null,
                        )
                      : DgPendingBackend(what: l.deviceWhat),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.courier, required this.kind});

  final BranchCourier courier;
  final CourierKind? kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = courier;
    return DgPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InitialsAvatar(
            name: c.name,
            size: 56,
            online: kind == CourierKind.out || kind == CourierKind.free,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: Dg.ui(size: 19, weight: FontWeight.w700, height: 1.2),
                ),
                if (c.code.isNotEmpty)
                  Text(c.code, style: Dg.ui(size: 13, color: Dg.text3)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (kind != null)
                      DgStatusPill.of(courierStatus(l, kind!), dense: true),
                    DgStatusPill(
                      label: l.poolStatus(c.status),
                      tone: c.active ? DgTone.ok : DgTone.neutral,
                      dense: true,
                    ),
                    if (c.primary)
                      DgStatusPill(
                        label: l.primaryBranch,
                        tone: DgTone.accent,
                        icon: LucideIcons.star,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: l.call,
            onPressed: c.phone == null
                ? null
                : () => dialNumber(context, c.phone),
            icon: const Icon(LucideIcons.phone, size: 20),
          ),
        ],
      ),
    );
  }
}

class _General extends StatelessWidget {
  const _General({
    required this.courier,
    required this.live,
    required this.kind,
    required this.shift,
    required this.perf,
    required this.range,
    this.profile,
  });

  final BranchCourier courier;
  final CourierProfile? profile;
  final BranchCourierLive? live;
  final CourierKind? kind;
  final ShiftCourierRow? shift;
  final CourierPerformance? perf;
  final String? range;

  static String _pct(L10n l, num? v) {
    if (v == null) return '—';
    final n = v.toStringAsFixed(1);
    return l.isEn ? '$n%' : '%${n.replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = courier;
    final vehicle = (profile?.vehicleType.isNotEmpty ?? false)
        ? profile!.vehicleType
        : c.vehicleType;
    Widget panel(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DgPanel(
        title: title,
        child: Column(children: rows),
      ),
    );
    return Column(
      children: [
        panel(l.secContact, [
          DgInfoRow(
            icon: LucideIcons.phone,
            label: l.fieldPhone,
            value: c.phone == null ? '' : formatTrPhone(c.phone!),
          ),
          DgInfoRow(
            icon: LucideIcons.mail,
            label: l.email,
            value: c.email ?? '',
          ),
        ]),
        panel(l.tabGeneral, [
          DgInfoRow(icon: LucideIcons.hash, label: l.fieldCode, value: c.code),
          DgInfoRow(
            icon: LucideIcons.bike,
            label: l.fieldVehicle,
            value: [
              if (vehicle.isNotEmpty) l.vehicleType(vehicle),
              if (profile?.vehicleModel.isNotEmpty ?? false)
                profile!.vehicleModel,
            ].join(' · '),
          ),
          if (profile?.plate.isNotEmpty ?? false)
            DgInfoRow(
              icon: LucideIcons.rectangleHorizontal,
              label: l.fieldPlate,
              value: profile!.plate,
            ),
          if (c.workModel.isNotEmpty)
            DgInfoRow(
              icon: LucideIcons.briefcase,
              label: l.fieldWorkModel,
              value: l.workModel(c.workModel),
            ),
          DgInfoRow(
            icon: LucideIcons.mapPin,
            label: l.fieldRegion,
            value: [c.district, c.city].where((e) => e.isNotEmpty).join(', '),
          ),
          if (c.validFrom != null)
            DgInfoRow(
              icon: LucideIcons.calendar,
              label: l.fieldAssignedSince,
              value: _date(c.validFrom!),
            ),
        ]),
        panel(l.secLive, [
          DgInfoRow(
            icon: LucideIcons.activity,
            label: l.fieldStatus,
            value: kind == null
                ? l.poolStatus(c.status)
                : courierStatus(l, kind!).label,
          ),
          DgInfoRow(
            icon: LucideIcons.package,
            label: l.fieldOnHand,
            value: '${live?.holdingCount ?? c.shipmentCount}',
            trailing: (live?.overdueCount ?? 0) > 0
                ? DgStatusPill(
                    label: l.overdueCount(live!.overdueCount),
                    tone: DgTone.bad,
                    dense: true,
                  )
                : null,
          ),
          if (shift != null)
            DgInfoRow(
              icon: LucideIcons.clock,
              label: l.fieldShift,
              value: shift!.ranges.isEmpty
                  ? l.poolStatus(shift!.planStatus)
                  : shift!.ranges,
            ),
          if (live?.lastSeenAt != null)
            DgInfoRow(
              icon: LucideIcons.mapPinned,
              label: l.lastSeenAt('').trim(),
              value: subeClock(live!.lastSeenAt!),
            ),
        ]),
        panel(
          range == null
              ? l.secPerformance
              : '${l.secPerformance} · ${switch (range) {
                  'today' => l.rangeToday,
                  '30d' => l.range30d,
                  _ => l.range7d,
                }}',
          perf == null
              ? [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('—', style: Dg.typeCaption()),
                  ),
                ]
              : [
                  DgInfoRow(
                    icon: LucideIcons.packageCheck,
                    label: l.kpiDelivered,
                    value: '${perf!.delivered} / ${perf!.shipments}',
                  ),
                  DgInfoRow(
                    icon: LucideIcons.packageX,
                    label: l.kpiUndelivered,
                    value: '${perf!.failed}',
                  ),
                  DgInfoRow(
                    icon: LucideIcons.chartColumn,
                    label: l.perfDeliveryRate,
                    value: _pct(l, perf!.deliveryRate),
                  ),
                  DgInfoRow(
                    icon: LucideIcons.target,
                    label: l.perfFirstAttempt,
                    value: _pct(l, perf!.firstAttemptRate),
                  ),
                ],
        ),
      ],
    );
  }
}

/// Kurye kartı: lacivert kart yüzü, beyaz zeminde QR (her temada okunur),
/// geçerlilik. Yenile / iptal önerilen uca bağlı (docs/15 §10).
class _CardTab extends StatelessWidget {
  const _CardTab({
    required this.future,
    required this.courier,
    required this.ready,
    required this.onRenew,
    required this.onRevoke,
  });

  final Future<PartnerCard>? future;
  final BranchCourier courier;
  final bool ready;
  final VoidCallback? onRenew;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<PartnerCard>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const DgSkeleton(height: 380, radius: 20);
        }
        if (snap.hasError || snap.data == null || snap.data!.token.isEmpty) {
          return DgPanel(
            child: Text(
              snap.hasError
                  ? BranchWorkspace.describeError(snap.error!)
                  : l.cardFailed,
              style: Dg.ui(size: 14, color: Dg.bad),
            ),
          );
        }
        final card = snap.data!;
        return Column(
          children: [
            Appear(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF16205A), Dg.navy],
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: BrandWave(alignment: Alignment.bottomRight),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const DijigooMark(size: 32),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    card.branchName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Dg.ui(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: Dg.mutedOnNight,
                                    ),
                                  ),
                                ),
                                DgStatusPill(
                                  label: card.active
                                      ? l.couriersActiveTab
                                      : l.couriersPassiveTab,
                                  tone: card.active
                                      ? DgTone.ok
                                      : DgTone.neutral,
                                  dense: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: card.token,
                                size: 200,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              card.displayName.isEmpty
                                  ? courier.name
                                  : card.displayName,
                              textAlign: TextAlign.center,
                              style: Dg.ui(
                                size: 18,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              card.code.isEmpty ? courier.code : card.code,
                              style: Dg.ui(size: 14, color: Dg.mutedOnNight),
                            ),
                            if (card.expiresAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                l.cardValidUntil(_date(card.expiresAt!)),
                                style: Dg.ui(
                                  size: 14,
                                  color: Dg.mutedOnNight,
                                ).copyWith(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l.cardHint, style: Dg.typeCaption()),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DgButton(
                    key: const Key('card-renew'),
                    label: l.cardRenew,
                    icon: LucideIcons.refreshCw,
                    tone: DgButtonTone.secondary,
                    onPressed: onRenew,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DgButton(
                    key: const Key('card-revoke'),
                    label: l.cardCancelAction,
                    icon: LucideIcons.ban,
                    tone: DgButtonTone.secondary,
                    onPressed: onRevoke,
                  ),
                ),
              ],
            ),
            if (!ready)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.pendingBackendBodyFor(l.cardRenewWhat),
                  style: Dg.typeCaption(),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Evraklar: belge kalemleri (durum ve son geçerlilik), onay özeti.
class _DocsTab extends StatelessWidget {
  const _DocsTab({required this.docs, required this.loading});

  final CourierCompliance? docs;
  final bool loading;

  static DgTone _tone(String status) => switch (status) {
    'APPROVED' => DgTone.ok,
    'IN_REVIEW' || 'PENDING' => DgTone.warn,
    'MISSING' || 'NOT_UPLOADED' || 'REJECTED' || 'EXPIRED' => DgTone.bad,
    _ => DgTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (docs == null) {
      return loading
          ? const DgSkeleton(height: 220, radius: 16)
          : DgEmptyState(icon: LucideIcons.fileX, title: l.docsNoPackage);
    }
    final d = docs!;
    final overall = switch (d.documentStatus) {
      'COMPLETE' => (label: l.docsComplete, tone: DgTone.ok),
      'IN_REVIEW' => (label: l.docsInReview, tone: DgTone.warn),
      'MISSING' => (label: l.docsMissing(d.missing), tone: DgTone.bad),
      _ => (label: l.docsNoPackage, tone: DgTone.neutral),
    };
    return Column(
      children: [
        DgPanel(
          child: Row(
            children: [
              DgIconBadge(
                icon: d.operationReady
                    ? LucideIcons.shieldCheck
                    : LucideIcons.shieldAlert,
                tone: d.operationReady ? DgTone.ok : DgTone.warn,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.docsSummary(d.approved, d.required),
                      style: Dg.ui(size: 15, weight: FontWeight.w700),
                    ),
                    if (d.consentsTotal > 0)
                      Text(
                        l.consentsSummary(d.consentsAccepted, d.consentsTotal),
                        style: Dg.typeCaption(),
                      ),
                    if (d.operationReady)
                      Text(l.operationReady, style: Dg.typeCaption()),
                  ],
                ),
              ),
              DgStatusPill(
                label: overall.label,
                tone: overall.tone,
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (d.documents.isEmpty)
          DgEmptyState(icon: LucideIcons.fileX, title: l.docsNoPackage)
        else
          DgPanel(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Column(
              children: [
                for (final doc in d.documents)
                  DgDocRow(
                    icon: LucideIcons.fileText,
                    title: l.isEn && doc.titleEn.isNotEmpty
                        ? doc.titleEn
                        : (doc.titleTr.isNotEmpty ? doc.titleTr : doc.code),
                    subtitle: doc.expiresAt == null
                        ? null
                        : l.docExpires(_date(doc.expiresAt!)),
                    status: (
                      label: l.branchDocStatus(doc.status),
                      tone: _tone(doc.status),
                      icon: switch (_tone(doc.status)) {
                        DgTone.ok => LucideIcons.circleCheck,
                        DgTone.warn => LucideIcons.hourglass,
                        DgTone.bad => LucideIcons.circleAlert,
                        _ => LucideIcons.circleDashed,
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cihaz: model, işletim sistemi, uygulama sürümü, son görülme, izinler
/// (docs/15 §9). Kurye hiç giriş yapmadıysa boş durum.
class _DeviceTab extends StatelessWidget {
  const _DeviceTab({required this.profile, required this.loading});

  final CourierProfile? profile;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (profile == null && loading) {
      return const DgSkeleton(height: 220, radius: 16);
    }
    final d = profile?.device;
    if (d == null) {
      return DgPanel(child: Text(l.deviceNone, style: Dg.typeCaption()));
    }
    return Column(
      children: [
        DgPanel(
          child: Column(
            children: [
              DgInfoRow(
                icon: LucideIcons.smartphone,
                label: l.deviceModel,
                value: d.model,
              ),
              DgInfoRow(icon: LucideIcons.cpu, label: l.deviceOs, value: d.os),
              DgInfoRow(
                icon: LucideIcons.appWindow,
                label: l.deviceApp,
                value: d.appVersion,
              ),
              if (d.lastSeenAt != null)
                DgInfoRow(
                  icon: LucideIcons.clock,
                  label: l.deviceLastSeen,
                  value: '${_date(d.lastSeenAt!)} ${subeClock(d.lastSeenAt!)}',
                ),
            ],
          ),
        ),
        if (d.permissions.isNotEmpty) ...[
          const SizedBox(height: 12),
          DgPanel(
            title: l.devicePermsTitle,
            child: Column(
              children: [
                for (final e in d.permissions.entries)
                  DgInfoRow(
                    label: l.devicePerm(e.key),
                    value: '',
                    trailing: DgStatusPill(
                      label: e.value ? l.permOn : l.permOff,
                      tone: e.value ? DgTone.ok : DgTone.warn,
                      dense: true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
