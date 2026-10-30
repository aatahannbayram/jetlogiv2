import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_features.dart';
import '../l10n.dart';
import '../motion.dart';
import '../scan.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_courier_detail_screen.dart';
import 'sube_courier_map_screen.dart';
import 'sube_header.dart';
import 'sube_widgets.dart';

/// Kuryeler (mockup 14): Aktif / Pasif sekmeleri, arama, canlı durum hapı,
/// üzerindeki paket ve eksik evrak uyarısı. Satır kurye detayını açar.
/// Liste agency/couriers ucundan; canlı durum panodan, evrak uyum ucundan.
class SubeCouriersScreen extends ConsumerStatefulWidget {
  const SubeCouriersScreen({super.key});

  @override
  ConsumerState<SubeCouriersScreen> createState() => _SubeCouriersScreenState();
}

class _SubeCouriersScreenState extends ConsumerState<SubeCouriersScreen> {
  Timer? _tick;
  int _tab = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final branch = ref.read(sessionProvider).branch;
      branch.loadRoster();
      // Molada olanlar vardiya kaydından gelir.
      if (branch.shiftDay == null) branch.loadDashExtras();
    });
    // Ekran açıkken canlı durum yarım dakikada bir yenilenir.
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

  Future<void> _newCourier() async {
    final branch = ref.read(sessionProvider).branch;
    final ready =
        branch.proposed(BranchFeatures.courierCreate) &&
        branch.capabilities.manage;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ready
            ? const _InviteSheet()
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: DgPendingBackend(what: context.l10n.newCourierWhat),
              ),
      ),
    );
    if (sent == true && mounted) subeSnack(context, context.l10n.inviteSent);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final live = {
      for (final c
          in branch.dashboard?.courierList ?? const <BranchCourierLive>[])
        c.id: c,
    };
    final docs = {
      for (final c in branch.compliance ?? const <CourierCompliance>[]) c.id: c,
    };
    // Liste gelmeden (ya da gelmezse) panodaki bağlı kuryeler gösterilir;
    // havuz durumu bilinmediği için hepsi Aktif sayılır.
    final all =
        branch.roster ??
        [
          for (final c in live.values)
            BranchCourier(
              id: c.id,
              name: c.name,
              code: c.code,
              phone: c.phone,
              status: 'ACTIVE',
              vehicleType: c.vehicleType,
            ),
        ];
    final active = [
      for (final c in all)
        if (c.active) c,
    ];
    final passive = [
      for (final c in all)
        if (!c.active) c,
    ];
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final c in _tab == 0 ? active : passive)
        if (q.isEmpty ||
            [
              c.name,
              c.code,
              c.district,
              c.phone ?? '',
            ].any((v) => v.toLowerCase().contains(q)))
          c,
    ];
    final onBreak = branch.couriersOnBreak;

    return Scaffold(
      appBar: const SubeHeaderBar(),
      // Başlık ve arama listeyle kayar, Aktif / Pasif sekmeleri yapışık kalır.
      body: DgStickyList(
        onRefresh: () async {
          await branch.refresh();
          await branch.loadRoster();
        },
        header: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: DgPageTitle(
              l.subeCouriersTitle,
              subtitle: l.couriersCount(all.length),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l.showOnMap,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SubeCourierMapScreen(),
                      ),
                    ),
                    icon: Icon(LucideIcons.map, color: Dg.highlight),
                  ),
                  TextButton.icon(
                    key: const Key('new-courier'),
                    onPressed: _newCourier,
                    icon: const Icon(LucideIcons.userPlus, size: 18),
                    label: Text(l.newCourier),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DgSearchField(
              hint: l.searchCouriersHint,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 2),
        ],
        pinned: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DgPillTabs(
            labels: [l.couriersActiveTab, l.couriersPassiveTab],
            counts: [active.length, passive.length],
            index: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        itemCount: shown.isEmpty ? 0 : shown.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return SubeStatusBanner(branch: branch, onRetry: branch.loadRoster);
          }
          final c = shown[i - 1];
          final row = Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CourierRosterTile(
              courier: c,
              live: live[c.id],
              docs: docs[c.id],
              onBreak: onBreak.contains(c.id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SubeCourierDetailScreen(courier: c),
                ),
              ),
            ),
          );
          return i <= 6 ? StaggerIn(index: i - 1, child: row) : row;
        },
        empty: Column(
          children: [
            SubeStatusBanner(branch: branch, onRetry: branch.loadRoster),
            if (branch.loading && branch.roster == null)
              for (var k = 0; k < 4; k++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: DgSkeleton(height: 76, radius: 16),
                )
            else
              DgEmptyState(icon: LucideIcons.users, title: l.emptyCouriers),
          ],
        ),
      ),
    );
  }
}

/// Kurye satırı: baş harf (çevrimiçi noktası), ad, kod · araç · bölge,
/// durum hapı, üzerindeki paket ve eksik evrak uyarısı.
class CourierRosterTile extends StatelessWidget {
  const CourierRosterTile({
    super.key,
    required this.courier,
    required this.onTap,
    this.live,
    this.docs,
    this.onBreak = false,
  });

  final BranchCourier courier;
  final BranchCourierLive? live;
  final CourierCompliance? docs;
  final bool onBreak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = courier;
    final kind = live == null || !c.active
        ? null
        : courierKind(live!, onBreak: onBreak);
    final holding = live?.holdingCount ?? c.shipmentCount;
    final missing = docs?.missing ?? 0;
    return DgPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          InitialsAvatar(
            name: c.name,
            size: 44,
            online: kind == CourierKind.out || kind == CourierKind.free,
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
                    if (c.code.isNotEmpty) c.code,
                    if (c.vehicleType.isNotEmpty) l.vehicleType(c.vehicleType),
                    if (c.district.isNotEmpty) c.district,
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
                      DgStatusPill.of(courierStatus(l, kind), dense: true)
                    else
                      DgStatusPill(
                        label: l.poolStatus(c.status),
                        tone: DgTone.neutral,
                        dense: true,
                      ),
                    if (missing > 0)
                      DgStatusPill(
                        label: l.docsMissing(missing),
                        tone: DgTone.bad,
                        icon: LucideIcons.fileWarning,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$holding',
                style: Dg.stat(size: 20, weight: FontWeight.w700),
              ),
              Text(
                l.fieldOnHand,
                style: Dg.ui(size: 14, color: Dg.text3).copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
        ],
      ),
    );
  }
}

/// Yeni kurye daveti (docs/15 §8): ad, telefon, araç, plaka. Kuryeye SMS
/// ile kayıt bağlantısı gider.
class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet();

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  static const _vehicles = ['MOTORCYCLE', 'CAR', 'BICYCLE', 'VAN', 'ON_FOOT'];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();
  String _vehicle = _vehicles.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(sessionProvider)
        .branch
        .inviteCourier(
          fullName: _name.text,
          phone: _phone.text,
          vehicleType: _vehicle,
          plate: _plate.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final motorized = const {'MOTORCYCLE', 'CAR', 'VAN'}.contains(_vehicle);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.inviteTitle, style: Dg.ui(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(l.inviteBody, style: Dg.typeCaption()),
          const SizedBox(height: 12),
          TextField(
            key: const Key('invite-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: l.inviteName),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('invite-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: l.invitePhone,
              prefixText: '+90 ',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _vehicles)
                ChoiceChip(
                  label: Text(l.vehicleType(v)),
                  selected: _vehicle == v,
                  onSelected: (_) => setState(() => _vehicle = v),
                ),
            ],
          ),
          if (motorized) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('invite-plate'),
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: l.fieldPlate),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Dg.hi,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 12),
          DgButton(
            key: const Key('invite-send'),
            label: l.inviteSend,
            busy: _busy,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
