import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/agency_client.dart';
import '../api/agency_models.dart';
import '../api/branch_models.dart';
import '../data/vault.dart';
import '../l10n.dart';
import '../scan.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import '../zpl_printer.dart';
import 'sube_widgets.dart';

String _dayTime(Object? raw) {
  final at = raw is String ? DateTime.tryParse(raw) : null;
  if (at == null) return '';
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

String _clock(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

/// Tek seferde okunan şube ekranları için yükle / hata / içerik iskeleti.
class _Loaded<T> extends StatefulWidget {
  const _Loaded({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
    this.bottom,
  });

  final String title;
  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data) builder;
  final Widget? Function(BuildContext context, T data)? bottom;

  @override
  State<_Loaded<T>> createState() => _LoadedState<T>();
}

class _LoadedState<T> extends State<_Loaded<T>> {
  T? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() async {
    try {
      final data = await widget.load();
      if (mounted) {
        setState(() {
          _data = data;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = _data;
    final bottom = data == null ? null : widget.bottom?.call(context, data);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (_failed && data == null)
                    DgRetryBanner(
                      message: l.reportFailedLoad,
                      onRetry: reload,
                      retryLabel: l.retryNow,
                    )
                  else if (data == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ...widget.builder(context, data),
                ],
              ),
            ),
          ),
          if (bottom != null)
            Material(
              color: Dg.surface,
              elevation: 8,
              shadowColor: const Color(0x1412191A),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: bottom,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _empty(String text) => Padding(
  padding: const EdgeInsets.only(top: 48),
  child: Center(
    child: Text(text, style: Dg.ui(size: 15, color: Dg.ink2)),
  ),
);

AgencyPortalApi _api(WidgetRef ref) => ref.read(sessionProvider).agency!;

typedef _Prep = ({Map<String, dynamic> kpis, List<BranchShipmentRow> rows});

/// Hazırlık listesi: kurye bekleyen gönderiler; seçilenlerin etiketi basılır.
class SubePrepScreen extends ConsumerStatefulWidget {
  const SubePrepScreen({super.key});

  @override
  ConsumerState<SubePrepScreen> createState() => _SubePrepScreenState();
}

class _SubePrepScreenState extends ConsumerState<SubePrepScreen> {
  final _picked = <String>{};
  bool _printing = false;

  Future<void> _print() async {
    final l = context.l10n;
    final host = ref.read(sessionProvider).branch.printerHost;
    if (host.isEmpty) {
      subeSnack(context, l.prepPrinterMissing);
      return;
    }
    setState(() => _printing = true);
    try {
      final rows = await _api(ref).fetchPrintRows(_picked.toList());
      for (final row in rows) {
        await sendZplToPrinter(host, shipmentLabelZpl(row));
      }
      if (!mounted) return;
      subeSnack(context, l.prepPrinted(rows.length));
      setState(_picked.clear);
    } on AgencyApiException catch (e) {
      if (mounted) subeSnack(context, e.serverMessage ?? l.reportFailedLoad);
    } catch (_) {
      if (mounted)
        subeSnack(context, l.prepPrinterDown(printerDisplayName(host)));
    }
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Loaded<_Prep>(
      title: l.prepTitle,
      load: _api(ref).fetchPreparation,
      bottom: (context, data) => _picked.isEmpty
          ? null
          : DgButton(
              label: l.prepPrint(_picked.length),
              icon: LucideIcons.printer,
              busy: _printing,
              onPressed: _print,
            ),
      builder: (context, data) => [
        SubeKpiGrid([
          (l.prepWaiting, '${data.kpis['awaitingCourier'] ?? 0}'),
          (l.prepPrepared, '${data.kpis['preparedToday'] ?? 0}'),
          (l.prepDispatched, '${data.kpis['dispatchedToday'] ?? 0}'),
        ]),
        if (data.rows.isEmpty) _empty(l.prepEmpty),
        for (final r in data.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DgChoiceSurface(
              selected: _picked.contains(r.shipmentId),
              onTap: () => setState(() {
                if (!_picked.remove(r.shipmentId)) _picked.add(r.shipmentId);
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.shipmentNumber} · ${r.recipientName}',
                            style: Dg.ui(size: 15, weight: FontWeight.w700),
                          ),
                          Text(
                            [
                              r.district,
                              r.addressLine,
                            ].where((e) => e.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Dg.ui(size: 13, color: Dg.ink3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    DgSelectMark(selected: _picked.contains(r.shipmentId)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Onay bekleyen gelen duyurular ve şubenin yayımladıkları.
class SubeAnnouncementsScreen extends ConsumerStatefulWidget {
  const SubeAnnouncementsScreen({super.key});

  @override
  ConsumerState<SubeAnnouncementsScreen> createState() =>
      _SubeAnnouncementsScreenState();
}

class _SubeAnnouncementsScreenState
    extends ConsumerState<SubeAnnouncementsScreen> {
  final _list = GlobalKey<_LoadedState<Map<String, dynamic>>>();

  Future<void> _act(String id, String action) async {
    final l = context.l10n;
    try {
      await _api(ref)
          .announcementAction(id, action, idempotencyKey: Vault.newUuid());
    } on AgencyApiException catch (e) {
      if (mounted) subeSnack(context, e.serverMessage ?? l.availabilityFailed);
    } catch (_) {
      if (mounted) subeSnack(context, l.availabilityFailed);
    }
    await _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Loaded<Map<String, dynamic>>(
      key: _list,
      title: l.annManageTitle,
      load: _api(ref).fetchAnnouncementsRaw,
      builder: (context, data) {
        List<Map> maps(Object? raw) => [
          for (final row in raw is List ? raw : const [])
            if (row is Map) row,
        ];
        final waiting = [
          for (final n in maps(data['announcements']))
            if ((n['announcement'] as Map?)?['requiresAck'] == true &&
                (n['announcement'] as Map?)?['acknowledgedAt'] == null)
              n,
        ];
        final mine = maps(data['published']);
        if (waiting.isEmpty && mine.isEmpty) return [_empty(l.annEmpty)];
        return [
          if (waiting.isNotEmpty) SubeSection(l.annIncoming),
          for (final n in waiting)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${n['title'] ?? ''}',
                      style: Dg.ui(size: 15, weight: FontWeight.w700),
                    ),
                    if ('${n['body'] ?? ''}'.isNotEmpty)
                      Text(
                        '${n['body']}',
                        style: Dg.ui(size: 14, color: Dg.ink2),
                      ),
                    const SizedBox(height: 10),
                    DgButton(
                      label: l.announcementAck,
                      icon: LucideIcons.check,
                      onPressed: () =>
                          _act('${(n['announcement'] as Map)['id']}', 'ack'),
                    ),
                  ],
                ),
              ),
            ),
          if (mine.isNotEmpty) SubeSection(l.annMine),
          for (final a in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a['title'] ?? ''}',
                            style: Dg.ui(size: 15, weight: FontWeight.w700),
                          ),
                          Text(
                            [
                              l.annStatus('${a['status'] ?? ''}'),
                              _dayTime(a['publishedAt']),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: Dg.ui(size: 13, color: Dg.ink3),
                          ),
                          if (a['stats'] is Map)
                            Text(
                              l.annStats(
                                ((a['stats'] as Map)['recipients'] as num?)
                                        ?.toInt() ??
                                    0,
                                ((a['stats'] as Map)['read'] as num?)
                                        ?.toInt() ??
                                    0,
                                ((a['stats'] as Map)['acknowledged'] as num?)
                                        ?.toInt() ??
                                    0,
                              ),
                              style: Dg.ui(size: 13, color: Dg.ink3),
                            ),
                        ],
                      ),
                    ),
                    if (a['status'] == 'DRAFT')
                      TextButton(
                        onPressed: () => _act('${a['id']}', 'publish'),
                        child: Text(l.annPublish),
                      )
                    else if (a['status'] == 'PUBLISHED')
                      TextButton(
                        onPressed: () => _act('${a['id']}', 'archive'),
                        child: Text(l.annArchive),
                      ),
                  ],
                ),
              ),
            ),
        ];
      },
    );
  }
}

/// Bugünün vardiyaları; başlangıç ve bitiş saati nedeniyle düzeltilir.
class SubeShiftFixScreen extends ConsumerStatefulWidget {
  const SubeShiftFixScreen({super.key});

  @override
  ConsumerState<SubeShiftFixScreen> createState() => _SubeShiftFixScreenState();
}

class _SubeShiftFixScreenState extends ConsumerState<SubeShiftFixScreen> {
  final _list = GlobalKey<_LoadedState<Map<String, dynamic>>>();

  Future<void> _fix(String name, Map shift) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShiftFixSheet(name: name, shift: shift),
    );
    if (saved == true) await _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Loaded<Map<String, dynamic>>(
      key: _list,
      title: l.shiftFixTitle,
      load: _api(ref).fetchCourierShiftsRaw,
      builder: (context, data) {
        final rows = [
          for (final c in data['couriers'] as List? ?? const [])
            if (c is Map)
              for (final s in c['shifts'] as List? ?? const [])
                if (s is Map && s['id'] is String)
                  (
                    name: '${(c['courier'] as Map?)?['fullName'] ?? ''}',
                    shift: s,
                  ),
        ];
        if (rows.isEmpty) return [_empty(l.shiftFixEmpty)];
        return [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                onTap: () => _fix(r.name, r.shift),
                child: Row(
                  children: [
                    InitialsAvatar(name: r.name, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: Dg.ui(size: 15, weight: FontWeight.w600),
                          ),
                          Text(
                            [
                              _dayTime(r.shift['startedAt']),
                              r.shift['endedAt'] == null
                                  ? l.shiftStillOpen
                                  : _dayTime(r.shift['endedAt'])
                                        .split(' ')
                                        .last,
                            ].join(' – '),
                            style: Dg.ui(size: 13, color: Dg.ink3),
                          ),
                        ],
                      ),
                    ),
                    DgIcon(LucideIcons.pencil, size: 16, color: Dg.ink3),
                  ],
                ),
              ),
            ),
        ];
      },
    );
  }
}

class _ShiftFixSheet extends ConsumerStatefulWidget {
  const _ShiftFixSheet({required this.name, required this.shift});

  final String name;
  final Map shift;

  @override
  ConsumerState<_ShiftFixSheet> createState() => _ShiftFixSheetState();
}

class _ShiftFixSheetState extends ConsumerState<_ShiftFixSheet> {
  late DateTime _start =
      DateTime.tryParse('${widget.shift['startedAt']}')?.toLocal() ??
      DateTime.now();
  late DateTime? _end = DateTime.tryParse('${widget.shift['endedAt']}')
      ?.toLocal();
  late final _originalStart = _start;
  late final _originalEnd = _end;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final base = start ? _start : (_end ?? DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    final day = start ? _start : (_end ?? _start);
    final value = DateTime(
      day.year,
      day.month,
      day.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      _error = null;
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = l.shiftFixNeedReason);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api(ref).correctShift(
        '${widget.shift['id']}',
        startedAt: _start == _originalStart ? null : _start,
        endedAt: _end == _originalEnd ? null : _end,
        reason: _reason.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AgencyApiException
            ? l.shiftFixError(e.code, e.serverMessage)
            : l.availabilityFailed;
      });
      return;
    }
    if (!mounted) return;
    subeSnack(context, l.shiftFixSaved);
    Navigator.of(context).pop(true);
  }

  Widget _time(String label, String value, VoidCallback onTap) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Dg.ui(size: 13, color: Dg.ink3)),
        const SizedBox(height: 4),
        DgButton(label: value, tone: DgButtonTone.secondary, onPressed: onTap),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.name, style: Dg.ui(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _time(l.shiftFixStart, _clock(_start), () => _pick(start: true)),
              const SizedBox(width: 10),
              _time(
                l.shiftFixEnd,
                _end == null ? '—' : _clock(_end!),
                () => _pick(start: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 500,
            decoration: InputDecoration(hintText: l.shiftFixReason),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(
                color: Dg.hi,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 10),
          DgButton(label: l.editSave, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

/// Şube ve kurye kartları: QR göster, okut ve doğrula.
class SubeCardsScreen extends ConsumerWidget {
  const SubeCardsScreen({super.key});

  Future<void> _show(
    BuildContext context,
    WidgetRef ref, {
    required String ownerType,
    required String ownerId,
    required String name,
  }) async {
    final l = context.l10n;
    final Map<String, dynamic> card;
    try {
      card = await _api(ref).createCard(
        ownerType: ownerType,
        ownerId: ownerId,
        // Aynı gün aynı sahip için aynı kart döner; anahtar da öyle.
        idempotencyKey:
            'card-$ownerType-$ownerId-${DateTime.now().toUtc().toIso8601String().substring(0, 10)}',
      );
    } on AgencyApiException catch (e) {
      if (context.mounted) subeSnack(context, e.serverMessage ?? l.cardFailed);
      return;
    } catch (_) {
      if (context.mounted) subeSnack(context, l.cardFailed);
      return;
    }
    final token = '${card['token'] ?? ''}';
    if (!context.mounted || token.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: Dg.ui(size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              // QR her temada okunabilsin diye beyaz zeminde.
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: token, size: 240),
              ),
              if (card['expiresAt'] is String) ...[
                const SizedBox(height: 10),
                Text(
                  sheet.l10n.cardValidUntil(
                    _dayTime(card['expiresAt']).split(' ').first,
                  ),
                  style: Dg.ui(size: 13, color: Dg.ink3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final AgencyDto? agency = ref.watch(sessionProvider).agencyUser?.agency;
    return _Loaded<List<Map<String, dynamic>>>(
      title: l.cardsTitle,
      load: _api(ref).fetchAgencyCouriers,
      builder: (context, couriers) => [
        DgButton(
          label: l.cardVerify,
          icon: LucideIcons.scanLine,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SubeCardVerifyScreen(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (agency != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DgCard(
              onTap: () => _show(
                context,
                ref,
                ownerType: 'BRANCH',
                ownerId: agency.id,
                name: agency.name,
              ),
              child: Row(
                children: [
                  IconTintBadge(
                    icon: LucideIcons.building2,
                    tint: Dg.amberBg,
                    ink: Dg.amber,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.cardBranch,
                      style: Dg.ui(size: 15, weight: FontWeight.w600),
                    ),
                  ),
                  DgIcon(LucideIcons.qrCode, size: 18, color: Dg.ink3),
                ],
              ),
            ),
          ),
        for (final c in couriers)
          if (c['courier'] is Map)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                onTap: () => _show(
                  context,
                  ref,
                  ownerType: 'COURIER',
                  ownerId: '${(c['courier'] as Map)['id']}',
                  name: '${(c['courier'] as Map)['fullName'] ?? ''}',
                ),
                child: Row(
                  children: [
                    InitialsAvatar(
                      name: '${(c['courier'] as Map)['fullName'] ?? ''}',
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${(c['courier'] as Map)['fullName'] ?? ''}',
                        style: Dg.ui(size: 15, weight: FontWeight.w600),
                      ),
                    ),
                    DgIcon(LucideIcons.qrCode, size: 18, color: Dg.ink3),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class SubeCardVerifyScreen extends ConsumerStatefulWidget {
  const SubeCardVerifyScreen({super.key});

  @override
  ConsumerState<SubeCardVerifyScreen> createState() =>
      _SubeCardVerifyScreenState();
}

class _SubeCardVerifyScreenState extends ConsumerState<SubeCardVerifyScreen> {
  Map<String, dynamic>? _result;
  String? _error;
  bool _busy = false;

  Future<void> _verify(String token) async {
    if (_busy) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await _api(ref).verifyCard(token.trim());
      if (mounted) setState(() => _result = res);
    } on AgencyApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'CARD_NOT_FOUND'
              ? l.cardNotFound
              : e.serverMessage ?? l.cardInvalid(null),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.availabilityFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = _result;
    final holder = r?['holder'] as Map?;
    final valid = r?['valid'] == true;
    return Scaffold(
      appBar: AppBar(title: Text(l.cardVerify)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          BarcodeScanPane(onDetect: _verify),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(
              _error!,
              style: Dg.ui(size: 16, weight: FontWeight.w700, color: Dg.hi),
            ),
          if (r != null)
            DgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DgIcon(
                        valid ? LucideIcons.circleCheck : LucideIcons.circleX,
                        size: 22,
                        color: valid ? Dg.sage : Dg.hi,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          valid
                              ? l.cardValid
                              : l.cardInvalid(r['reason'] as String?),
                          style: Dg.ui(
                            size: 17,
                            weight: FontWeight.w700,
                            color: valid ? Dg.sage : Dg.hi,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (holder != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${holder['displayName'] ?? ''}',
                      style: Dg.ui(size: 16, weight: FontWeight.w600),
                    ),
                    Text(
                      [
                        '${holder['code'] ?? ''}',
                        '${holder['branchName'] ?? ''}',
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: Dg.ui(size: 13, color: Dg.ink3),
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

typedef _AgencyInfo = ({
  List<Map<String, dynamic>> couriers,
  List<Map<String, dynamic>> regions,
  List<Map<String, dynamic>> warehouses,
});

/// Acenteye bağlı kuryeler, hizmet bölgeleri ve depolar.
class SubeAgencyInfoScreen extends ConsumerWidget {
  const SubeAgencyInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final api = _api(ref);
    return _Loaded<_AgencyInfo>(
      title: l.agencyInfoTitle,
      load: () async => (
        couriers: await api.fetchAgencyCouriers(),
        regions: await api.fetchAgencyRegions(),
        warehouses: await api.fetchAgencyWarehouses(),
      ),
      builder: (context, data) => [
        SubeSection(l.agencyCouriers, trailing: '${data.couriers.length}'),
        for (final c in data.couriers)
          if (c['courier'] is Map)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DgCard(
                child: Row(
                  children: [
                    InitialsAvatar(
                      name: '${(c['courier'] as Map)['fullName'] ?? ''}',
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(c['courier'] as Map)['fullName'] ?? ''}',
                            style: Dg.ui(size: 15, weight: FontWeight.w600),
                          ),
                          Text(
                            [
                              '${(c['courier'] as Map)['districtName'] ?? ''}',
                              l.vehicle(
                                '${(c['courier'] as Map)['vehicleType'] ?? ''}',
                              ),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: Dg.ui(size: 13, color: Dg.ink3),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      l.shipmentsCount(
                        (c['shipmentCount'] as num?)?.toInt() ?? 0,
                      ),
                      style: Dg.ui(size: 13, color: Dg.ink2),
                    ),
                  ],
                ),
              ),
            ),
        SubeSection(l.agencyRegions, trailing: '${data.regions.length}'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in data.regions)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Dg.elev,
                  borderRadius: BorderRadius.circular(Dg.radius),
                ),
                child: Text(
                  [
                        ...(((r['region'] as Map?)?['geography']
                                    as Map?)?['districts']
                                as List? ??
                            const []),
                      ].isNotEmpty
                      ? (((r['region'] as Map)['geography'] as Map)['districts']
                                as List)
                            .join(', ')
                      : '${(r['region'] as Map?)?['name'] ?? ''}',
                  style: Dg.ui(size: 14, weight: FontWeight.w600),
                ),
              ),
          ],
        ),
        SubeSection(l.agencyWarehouses, trailing: '${data.warehouses.length}'),
        if (data.warehouses.isEmpty)
          Text(l.agencyNoWarehouse, style: Dg.ui(size: 14, color: Dg.ink3)),
        for (final w in data.warehouses)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DgCard(
              child: Text(
                '${(w['warehouse'] as Map?)?['name'] ?? w['name'] ?? ''}',
                style: Dg.ui(size: 15, weight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fatura ve hakediş: liste backend'de hazır olana kadar yalnız talepler.
class SubeInvoicesScreen extends ConsumerStatefulWidget {
  const SubeInvoicesScreen({super.key});

  @override
  ConsumerState<SubeInvoicesScreen> createState() => _SubeInvoicesScreenState();
}

class _SubeInvoicesScreenState extends ConsumerState<SubeInvoicesScreen> {
  final _list = GlobalKey<_LoadedState<Map<String, dynamic>>>();
  final _note = TextEditingController();
  String _category = 'REQUEST';
  String? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    final typed = _category == 'DISPUTE' || _category == 'REQUEST';
    if (_category == 'DISPUTE' && _reason == null) {
      setState(() => _error = l.invoiceNeedReason);
      return;
    }
    if (typed && _note.text.trim().length < 5) {
      setState(() => _error = l.invoiceNeedNote);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api(ref).createInvoiceSupport(
        category: _category,
        reasonKey: _category == 'DISPUTE' ? _reason : null,
        note: _note.text.trim(),
        idempotencyKey: Vault.newUuid(),
      );
    } on AgencyApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.serverMessage ?? l.availabilityFailed;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.availabilityFailed;
        });
      }
      return;
    }
    if (!mounted) return;
    _note.clear();
    setState(() {
      _busy = false;
      _reason = null;
    });
    subeSnack(context, l.invoiceSent);
    await _list.currentState?.reload();
  }

  Widget _chips(
    List<String> codes,
    String? selected,
    String Function(String) label,
    ValueChanged<String> onPick,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final c in codes)
        DgChoiceSurface(
          selected: selected == c,
          onTap: () => setState(() {
            _error = null;
            onPick(c);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label(c),
              style: Dg.ui(size: 15, weight: FontWeight.w600),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Loaded<Map<String, dynamic>>(
      key: _list,
      title: l.invoicesTitle,
      load: _api(ref).fetchInvoices,
      builder: (context, data) {
        List<String> strings(Object? raw, List<String> fallback) {
          final out = [
            for (final v in raw is List ? raw : const [])
              if (v is String) v,
          ];
          return out.isEmpty ? fallback : out;
        }

        final categories = strings(data['supportCategories'], const [
          'DISPUTE',
          'REQUEST',
          'CALL_REQUEST',
          'LIVE_CHAT',
        ]);
        final reasons = strings(data['disputeReasons'], const ['OTHER']);
        final cases = [
          for (final c in data['supportCases'] as List? ?? const [])
            if (c is Map) c,
        ];
        final typed = _category == 'DISPUTE' || _category == 'REQUEST';
        return [
          if (data['schemaReady'] != true)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l.invoicesNotReady,
                style: Dg.ui(size: 14, color: Dg.ink2),
              ),
            ),
          SubeSection(l.invoiceNewRequest),
          _chips(
            categories,
            _category,
            l.invoiceCategory,
            (c) => _category = c,
          ),
          if (_category == 'DISPUTE') ...[
            SubeSection(l.invoiceReasonTitle),
            _chips(reasons, _reason, l.invoiceReason, (c) => _reason = c),
          ],
          if (typed) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(hintText: l.invoiceNoteHint),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: Dg.ui(size: 15, weight: FontWeight.w600, color: Dg.bad),
              ),
            ),
          const SizedBox(height: 12),
          DgButton(
            label: l.invoiceSend,
            icon: LucideIcons.send,
            busy: _busy,
            onPressed: _send,
          ),
          if (cases.isNotEmpty) SubeSection(l.invoicePast),
          for (final c in cases)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c['subject'] ?? l.invoiceCategory('${c['category'] ?? ''}')}',
                      style: Dg.ui(size: 15, weight: FontWeight.w700),
                    ),
                    Text(
                      [
                        '${c['caseNumber'] ?? ''}',
                        l.caseStatus('${c['statusCode'] ?? ''}'),
                        _dayTime(c['createdAt']),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: Dg.ui(size: 13, color: Dg.ink3),
                    ),
                  ],
                ),
              ),
            ),
        ];
      },
    );
  }
}
