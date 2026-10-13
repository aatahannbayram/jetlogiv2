import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/panel_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _dayTime(Object? raw) {
  final at = raw is String ? DateTime.tryParse(raw) : null;
  if (at == null) return '';
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

/// Yükle / hata / içerik iskeleti: sunucudan tek seferde okunan ekranlar.
class _Loaded<T> extends StatefulWidget {
  const _Loaded({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
  });

  final String title;
  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data) builder;

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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
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
    );
  }
}

Widget _empty(String text) => Padding(
  padding: const EdgeInsets.only(top: 48),
  child: Center(
    child: Text(text, style: Dg.ui(size: 15, color: Dg.ink2)),
  ),
);

Widget _section(String text) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 8),
  child: Text(
    text,
    style: Dg.ui(size: 14, weight: FontWeight.w600, color: Dg.ink2),
  ),
);

Widget _stat(String label, String value) => DgCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Dg.ui(size: 13, color: Dg.ink3)),
      const SizedBox(height: 4),
      Mono(value, size: 22, weight: FontWeight.w700),
    ],
  ),
);

/// Seviye, teslim sayıları ve rozetler.
class ProfileSummaryScreen extends ConsumerWidget {
  const ProfileSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return _Loaded<Map<String, dynamic>>(
      title: l.summaryTitle,
      load: () => ref.read(sessionProvider).panel!.fetchProfileSummary(),
      builder: (context, data) {
        final courier = data['courier'] as Map? ?? const {};
        final stats = data['stats'] as Map? ?? const {};
        final rate = stats['successRate'] as num?;
        return [
          DgCard(
            child: Row(
              children: [
                InitialsAvatar(name: '${courier['fullName'] ?? ''}', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${courier['fullName'] ?? ''}',
                        style: Dg.ui(size: 16, weight: FontWeight.w700),
                      ),
                      Mono(
                        '${courier['courierCode'] ?? ''}',
                        size: 12,
                        color: Dg.ink3,
                      ),
                    ],
                  ),
                ),
                Text(
                  l.tier('${courier['tier'] ?? ''}'),
                  style: Dg.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Dg.mid,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stat(
                  l.summaryDelivered,
                  '${stats['totalDelivered'] ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  l.summarySuccess,
                  rate == null
                      ? '—'
                      : '%${rate.toStringAsFixed(1).replaceAll('.', ',')}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stat(
                  l.summaryLast30,
                  '${stats['last30Delivered'] ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  l.summaryLast30Failed,
                  '${stats['last30Failed'] ?? 0}',
                ),
              ),
            ],
          ),
          _section(l.summaryBadges),
          for (final b in data['badges'] as List? ?? const [])
            if (b is Map && b['code'] != 'TRAINING_LEADER')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DgCard(
                  child: Row(
                    children: [
                      DgIcon(
                        b['earned'] == true
                            ? LucideIcons.award
                            : LucideIcons.circleDashed,
                        size: 22,
                        color: b['earned'] == true ? Dg.sage : Dg.ink3,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.badge('${b['code']}'),
                          style: Dg.ui(size: 15, weight: FontWeight.w600),
                        ),
                      ),
                      Mono(
                        '${b['progress'] ?? 0} / ${b['target'] ?? 0}',
                        size: 13,
                        color: Dg.ink3,
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

/// Başvuruda verilen onaylar.
class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return _Loaded<Map<String, dynamic>>(
      title: l.contractsTitle,
      load: () => ref.read(sessionProvider).panel!.fetchMyContracts(),
      builder: (context, data) {
        final rows = [
          for (final c in data['consents'] as List? ?? const [])
            if (c is Map) c,
        ];
        if (rows.isEmpty) return [_empty(l.contractsEmpty)];
        return [
          for (final c in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text(
                        '${(l.isEn ? c['titleEn'] : c['titleTr']) ?? c['code'] ?? ''}',
                        style: Dg.ui(size: 15, weight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        l.consentDecision('${c['decision'] ?? ''}'),
                        style: Dg.ui(
                          size: 13,
                          color: c['accepted'] == true ? Dg.sage : Dg.ink3,
                        ),
                      ),
                      children: [
                        Text(
                          '${(l.isEn ? c['contentEn'] : c['contentTr']) ?? ''}',
                          style: Dg.ui(size: 14, color: Dg.ink2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ];
      },
    );
  }
}

/// Son 7 günün vardiyaları.
class ShiftHistoryScreen extends ConsumerWidget {
  const ShiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return _Loaded<Map<String, dynamic>>(
      title: l.shiftHistoryTitle,
      load: () => ref.read(sessionProvider).panel!.fetchShiftHistory(),
      builder: (context, data) {
        final summary = data['summary'] as Map? ?? const {};
        final items = [
          for (final s in data['items'] as List? ?? const [])
            if (s is Map) s,
        ];
        return [
          Row(
            children: [
              Expanded(
                child: _stat(l.shiftCount, '${summary['shiftCount'] ?? 0}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  l.shiftWorked,
                  l.duration((summary['workedMinutes'] as num?)?.toInt() ?? 0),
                ),
              ),
            ],
          ),
          if (items.isEmpty)
            _empty(l.shiftHistoryEmpty)
          else ...[
            const SizedBox(height: 14),
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          _dayTime(s['startedAt']),
                          s['endedAt'] == null
                              ? l.shiftStillOpen
                              : _dayTime(s['endedAt']).split(' ').last,
                        ].join(' – '),
                        style: Dg.ui(size: 15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${l.shiftWorked}: ${l.duration((s['workedMinutes'] as num?)?.toInt() ?? 0)}',
                          '${l.shiftBreaks}: ${l.duration((s['breakMinutes'] as num?)?.toInt() ?? 0)}',
                          if (s['status'] == 'AUTO_CLOSED') l.shiftAutoClosed,
                        ].join(' · '),
                        style: Dg.ui(size: 13, color: Dg.ink3),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ];
      },
    );
  }
}

/// Göreve yüklenen fotoğraf, imza ve belgeler; silinebilenler silinir.
class TaskEvidenceScreen extends ConsumerStatefulWidget {
  const TaskEvidenceScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskEvidenceScreen> createState() => _TaskEvidenceScreenState();
}

class _TaskEvidenceScreenState extends ConsumerState<TaskEvidenceScreen> {
  final _files = <String, Future<List<int>>>{};
  final _list = GlobalKey<_LoadedState<List<Map<String, dynamic>>>>();

  Future<void> _delete(String id) async {
    final l = context.l10n;
    try {
      await ref
          .read(sessionProvider)
          .panel!
          .deleteTaskEvidence(widget.taskId, id);
    } catch (_) {
      if (mounted) _snack(context, l.photoDeleteFailed);
      return;
    }
    await _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final panel = ref.read(sessionProvider).panel!;
    return _Loaded<List<Map<String, dynamic>>>(
      key: _list,
      title: l.photosTitle,
      load: () => panel.fetchTaskEvidence(widget.taskId),
      builder: (context, rows) {
        if (rows.isEmpty) return [_empty(l.photosEmpty)];
        return [
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e['evidenceType'] != 'NOTE')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Dg.radius),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: FutureBuilder<List<int>>(
                            future: _files.putIfAbsent(
                              '${e['id']}',
                              () => panel
                                  .fetchTaskEvidenceFile(
                                    widget.taskId,
                                    '${e['id']}',
                                  )
                                  .catchError((_) => const <int>[]),
                            ),
                            builder: (context, snap) {
                              final bytes = snap.data;
                              final image = '${e['mimeType'] ?? ''}'.startsWith(
                                'image/',
                              );
                              if (bytes == null || bytes.isEmpty || !image) {
                                return ColoredBox(
                                  color: Dg.elev,
                                  child: Center(
                                    child: DgIcon(
                                      image
                                          ? LucideIcons.image
                                          : LucideIcons.fileText,
                                      size: 28,
                                      color: Dg.ink3,
                                    ),
                                  ),
                                );
                              }
                              return Image.memory(
                                Uint8List.fromList(bytes),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              l.evidenceType('${e['evidenceType'] ?? ''}'),
                              _dayTime(e['capturedAt']),
                            ].where((x) => x.isNotEmpty).join(' · '),
                            style: Dg.ui(size: 14, weight: FontWeight.w600),
                          ),
                        ),
                        // Kapatılmış denemeye bağlanan kanıt silinemez.
                        if (e['deliveryAttemptId'] == null)
                          TextButton(
                            onPressed: () => _delete('${e['id']}'),
                            child: Text(
                              l.photoDelete,
                              style: TextStyle(color: Dg.hi),
                            ),
                          ),
                      ],
                    ),
                    if ('${e['note'] ?? ''}'.isNotEmpty)
                      Text(
                        '${e['note']}',
                        style: Dg.ui(size: 14, color: Dg.ink2),
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

/// Araç, çalışma şekli ve adres güncelleme. Değişiklik hemen uygulanır.
class ProfileChangeScreen extends ConsumerStatefulWidget {
  const ProfileChangeScreen({super.key});

  @override
  ConsumerState<ProfileChangeScreen> createState() =>
      _ProfileChangeScreenState();
}

class _ProfileChangeScreenState extends ConsumerState<ProfileChangeScreen> {
  static const _vehicles = [
    'MOTORCYCLE',
    'CAR',
    'BICYCLE',
    'PEDESTRIAN',
    'LIGHT_COMMERCIAL',
    'OTHER',
  ];
  static const _models = [
    'FULL_TIME',
    'PART_TIME',
    'PERIODIC',
    'WEEKEND',
    'SHIFT',
  ];
  static const _companies = [
    'NO_COMPANY',
    'SOLE_PROPRIETORSHIP',
    'ESTABLISHMENT_IN_PROGRESS',
    'AFFILIATED_WITH_ANOTHER_COMPANY',
  ];

  bool _loading = true;
  bool _failed = false;
  String? _busy;
  String? _error;
  String _vehicle = '';
  String _model = '';
  String _company = '';
  final _companyName = TextEditingController();
  final _address = TextEditingController();
  ({int id, String name})? _city;
  ({int id, String name})? _district;
  List<Map<String, dynamic>> _requests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _companyName.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final panel = ref.read(sessionProvider).panel!;
    try {
      final profile = await panel.fetchProfileRaw();
      final requests = await panel.fetchProfileChangeRequests();
      if (!mounted) return;
      ({int id, String name})? place(Object? raw) =>
          raw is Map && raw['id'] is num
          ? (id: (raw['id'] as num).toInt(), name: '${raw['name'] ?? ''}')
          : null;
      setState(() {
        _vehicle = '${profile['vehicleType'] ?? ''}';
        _model = '${profile['workModel'] ?? ''}';
        _company = '${profile['companyStatus'] ?? ''}';
        _companyName.text = '${profile['companyName'] ?? ''}';
        _city ??= place(profile['city']);
        _district ??= place(profile['district']);
        _requests = requests;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _send(String type, Map<String, Object?> data) async {
    final l = context.l10n;
    setState(() {
      _busy = type;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider)
          .panel!
          .createProfileChangeRequest(changeType: type, requestedData: data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = e is PanelApiException
            ? e.statusCode == null
                  ? l.visitOffline
                  : l.editError(e.code, e.serverMessage)
            : l.availabilityFailed;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = null);
    _snack(context, l.editSaved);
    unawaited(ref.read(sessionProvider).loadIdentity());
    await _load();
  }

  Future<({int id, String name})?> _pickPlace(
    String title,
    Future<List<({int id, String name})>> Function() load,
  ) => showModalBottomSheet<({int id, String name})>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SizedBox(
      height: MediaQuery.of(sheet).size.height * 0.7,
      child: FutureBuilder<List<({int id, String name})>>(
        future: load(),
        builder: (context, snap) {
          final rows = snap.data;
          if (rows == null) {
            return Center(
              child: snap.hasError
                  ? Text(context.l10n.reportFailedLoad)
                  : const CircularProgressIndicator(),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title,
                  style: Dg.ui(size: 18, weight: FontWeight.w700),
                ),
              ),
              for (final r in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.name, style: Dg.ui(size: 16)),
                  onTap: () => Navigator.of(sheet).pop(r),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _chips(
    List<String> codes,
    String selected,
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

  Widget _save(String type, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DgButton(
      label: context.l10n.editSave,
      tone: DgButtonTone.secondary,
      busy: _busy == type,
      onPressed: _busy == null ? onPressed : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final panel = ref.read(sessionProvider).panel!;
    return Scaffold(
      appBar: AppBar(title: Text(l.editInfoTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_failed)
            DgRetryBanner(
              message: l.reportFailedLoad,
              onRetry: _load,
              retryLabel: l.retryNow,
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Dg.hi,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            _section(l.editVehicle),
            _chips(_vehicles, _vehicle, l.vehicle, (c) => _vehicle = c),
            _save('VEHICLE', () => _send('VEHICLE', {'vehicleType': _vehicle})),
            _section(l.editWork),
            _chips(_models, _model, l.workModel, (c) => _model = c),
            _section(l.editCompany),
            _chips(_companies, _company, l.companyStatus, (c) => _company = c),
            if (_company == 'AFFILIATED_WITH_ANOTHER_COMPANY')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: _companyName,
                  decoration: InputDecoration(hintText: l.editCompanyName),
                ),
              ),
            _save('WORK', () {
              final other = _company == 'AFFILIATED_WITH_ANOTHER_COMPANY';
              if (other && _companyName.text.trim().isEmpty) {
                setState(() => _error = l.editCompanyNeeded);
                return;
              }
              _send('WORK', {
                'workModel': _model.isEmpty ? 'UNKNOWN' : _model,
                'companyStatus': _company.isEmpty ? 'UNKNOWN' : _company,
                if (other) 'companyName': _companyName.text.trim(),
              });
            }),
            _section(l.editAddress),
            Row(
              children: [
                Expanded(
                  child: DgButton(
                    label: _city?.name ?? l.editCity,
                    tone: DgButtonTone.secondary,
                    onPressed: () async {
                      final c = await _pickPlace(l.editCity, panel.fetchCities);
                      if (c == null || c.id == _city?.id) return;
                      setState(() {
                        _city = c;
                        _district = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DgButton(
                    label: _district?.name ?? l.editDistrict,
                    tone: DgButtonTone.secondary,
                    onPressed: _city == null
                        ? null
                        : () async {
                            final d = await _pickPlace(
                              l.editDistrict,
                              () => panel.fetchDistricts(_city!.id),
                            );
                            if (d != null) setState(() => _district = d);
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(hintText: l.editAddressLine),
            ),
            _save('ADDRESS', () {
              if (_city == null ||
                  _district == null ||
                  _address.text.trim().length < 5) {
                setState(() => _error = l.editAddressNeeded);
                return;
              }
              _send('ADDRESS', {
                'cityId': _city!.id,
                'districtId': _district!.id,
                'addressLine1': _address.text.trim(),
              });
            }),
            if (_requests.isNotEmpty) ...[
              _section(l.editPast),
              for (final r in _requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DgCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.changeType('${r['changeType'] ?? ''}'),
                                style: Dg.ui(size: 15, weight: FontWeight.w700),
                              ),
                              Text(
                                [
                                  l.requestStatus('${r['status'] ?? ''}'),
                                  _dayTime(r['createdAt']),
                                ].where((e) => e.isNotEmpty).join(' · '),
                                style: Dg.ui(size: 13, color: Dg.ink3),
                              ),
                            ],
                          ),
                        ),
                        if (r['status'] == 'PENDING')
                          TextButton(
                            onPressed: () async {
                              try {
                                await panel.cancelProfileChangeRequest(
                                  '${r['id']}',
                                );
                              } catch (_) {}
                              await _load();
                            },
                            child: Text(l.cancelRequest),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
