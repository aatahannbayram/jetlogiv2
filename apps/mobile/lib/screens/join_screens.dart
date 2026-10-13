import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/panel_models.dart';
import '../l10n.dart';
import '../privacy.dart';
import '../scan.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

typedef Place = ({int id, String name});

/// E-postadaki bağlantıdan `token` ve (evrak bağlantısında) `publicId` çıkarır.
/// Yalnız token yapıştırıldıysa onu token sayar.
({String? token, String? publicId}) parseJoinLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return (token: null, publicId: null);
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme) {
    return (token: text.contains(' ') ? null : text, publicId: null);
  }
  final token = uri.queryParameters['token'];
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  return (
    token: token == null || token.isEmpty ? null : token,
    publicId: segments.isEmpty ? null : segments.last,
  );
}

/// İlk şifre kuralı: 8–72 karakter; küçük harf, büyük harf ve rakam.
bool activationPasswordOk(String p) =>
    p.length >= 8 &&
    p.length <= 72 &&
    p.contains(RegExp(r'[a-zçğıöşü]')) &&
    p.contains(RegExp(r'[A-ZÇĞİÖŞÜ]')) &&
    p.contains(RegExp(r'\d'));

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Widget _error(String? text) => text == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          text,
          style: TextStyle(
            color: Dg.hi,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 8),
  child: Text(
    text,
    style: Dg.ui(size: 14, weight: FontWeight.w600, color: Dg.ink2),
  ),
);

String _apiError(L10n l, Object e, String Function(String, String?) map) =>
    e is PanelApiException
    ? e.statusCode == null
          ? l.visitOffline
          : map(e.code, e.serverMessage)
    : l.availabilityFailed;

Future<Place?> pickPlace(
  BuildContext context,
  String title,
  Future<List<Place>> Function() load,
) => showModalBottomSheet<Place>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => SizedBox(
    height: MediaQuery.of(sheet).size.height * 0.7,
    child: FutureBuilder<List<Place>>(
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

/// Giriş ekranından açılır: başvuru, hesap açma, evrak yükleme.
class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget row(IconData icon, String title, String sub, Widget screen) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DgCard(
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: Row(
              children: [
                IconTintBadge(
                  icon: icon,
                  tint: Dg.amberBg,
                  ink: Dg.amber,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Dg.ui(size: 16, weight: FontWeight.w700),
                      ),
                      Text(sub, style: Dg.ui(size: 13, color: Dg.ink3)),
                    ],
                  ),
                ),
                DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
              ],
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.joinTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          row(
            LucideIcons.userPlus,
            l.joinApply,
            l.joinApplySub,
            const ApplicationScreen(),
          ),
          row(
            LucideIcons.keyRound,
            l.joinActivate,
            l.joinActivateSub,
            const ActivateScreen(),
          ),
          row(
            LucideIcons.fileUp,
            l.joinDocs,
            l.joinDocsSub,
            const DocumentPortalScreen(),
          ),
        ],
      ),
    );
  }
}

/// E-postadaki bağlantıyla ilk şifreyi belirleme.
class ActivateScreen extends ConsumerStatefulWidget {
  const ActivateScreen({super.key});

  @override
  ConsumerState<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends ConsumerState<ActivateScreen> {
  final _link = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();
  String? _token;
  Map<String, dynamic>? _account;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _link.dispose();
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final l = context.l10n;
    final token = parseJoinLink(_link.text).token;
    if (token == null) {
      setState(() => _err = l.linkBad);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final account = await ref
          .read(sessionProvider)
          .panel!
          .validateActivation(token);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _token = token;
        _account = account;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = _apiError(l, e, l.joinLinkError);
      });
    }
  }

  Future<void> _activate() async {
    final l = context.l10n;
    if (_password.text != _again.text) {
      setState(() => _err = l.passwordMismatch);
      return;
    }
    if (!activationPasswordOk(_password.text)) {
      setState(() => _err = l.passwordWeak);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref
          .read(sessionProvider)
          .panel!
          .activateAccount(token: _token!, password: _password.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = _apiError(l, e, l.joinLinkError);
      });
      return;
    }
    if (!mounted) return;
    _snack(context, l.activateDone);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final account = _account;
    return PrivacyGate(
      active: account != null,
      child: Scaffold(
        appBar: AppBar(title: Text(l.joinActivate)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (account == null) ...[
              TextField(
                controller: _link,
                minLines: 2,
                maxLines: 4,
                autocorrect: false,
                decoration: InputDecoration(hintText: l.linkHint),
              ),
              _error(_err),
              const SizedBox(height: 16),
              DgButton(label: l.linkContinue, busy: _busy, onPressed: _check),
            ] else ...[
              Text(
                '${account['fullName'] ?? ''}',
                style: Dg.ui(size: 18, weight: FontWeight.w700),
              ),
              Text(
                '${account['email'] ?? ''}',
                style: Dg.ui(size: 14, color: Dg.ink3),
              ),
              _label(l.activatePassword),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(hintText: l.passwordNew),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _again,
                obscureText: true,
                decoration: InputDecoration(hintText: l.passwordAgain),
              ),
              const SizedBox(height: 10),
              Text(l.activateRules, style: Dg.ui(size: 14, color: Dg.ink2)),
              _error(_err),
              const SizedBox(height: 16),
              DgButton(
                label: l.joinActivate,
                icon: LucideIcons.keyRound,
                busy: _busy,
                onPressed: _activate,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bir onay metni için kullanıcının kararı ve okuma zamanları.
class _Consent {
  _Consent(this.def);

  final Map<String, dynamic> def;
  DateTime? openedAt;
  DateTime? scrolledAt;
  DateTime? decidedAt;
  String decision = 'NOT_SELECTED';

  bool get required => def['isRequired'] == true;
  String get mode => '${def['mode'] ?? 'ACCEPTANCE'}';
  bool get positive => decision == 'ACCEPTED' || decision == 'ACKNOWLEDGED';

  /// Seçimi yapılmış sayılır mı (isteğe bağlı olanlar hiç açılmasa da olur).
  bool get settled => required ? positive : true;

  Map<String, Object?> toJson() {
    final opened = openedAt ?? DateTime.now();
    return {
      'definitionId': def['definitionId'],
      'versionId': def['versionId'],
      'code': def['code'],
      'version': def['version'],
      'contentHash': def['contentHash'],
      'decision': decision,
      'viewedToEnd': scrolledAt != null,
      'openedAt': opened.toUtc().toIso8601String(),
      'scrollCompletedAt': (scrolledAt ?? opened).toUtc().toIso8601String(),
      'decidedAt': (decidedAt ?? opened).toUtc().toIso8601String(),
      'locale': 'tr',
    };
  }
}

class ApplicationScreen extends ConsumerStatefulWidget {
  const ApplicationScreen({super.key});

  @override
  ConsumerState<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends ConsumerState<ApplicationScreen> {
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
  static const _starts = [
    'IMMEDIATELY',
    'WITHIN_ONE_WEEK',
    'WITHIN_TWO_WEEKS',
    'PERIODIC_ONLY',
    'INFORMATION_ONLY',
  ];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _companyName = TextEditingController();
  Place? _city;
  Place? _district;
  String? _vehicle;
  String? _model;
  String? _company;
  String? _start;
  List<_Consent> _consents = const [];
  bool _busy = false;
  String? _err;
  String? _doneNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final rows = await ref
            .read(sessionProvider)
            .panel!
            .fetchApplicationConsents();
        if (mounted)
          setState(() => _consents = [for (final r in rows) _Consent(r)]);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _companyName.dispose();
    super.dispose();
  }

  bool get _needsCompanyName =>
      _company == 'SOLE_PROPRIETORSHIP' ||
      _company == 'AFFILIATED_WITH_ANOTHER_COMPANY';

  Future<void> _read(_Consent c) async {
    c.openedAt ??= DateTime.now();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _ConsentReader(consent: c)));
    if (mounted) setState(() => _err = null);
  }

  Future<void> _send() async {
    final l = context.l10n;
    final panel = ref.read(sessionProvider).panel!;
    final name = _name.text.trim();
    final filled =
        name.split(RegExp(r'\s+')).length >= 2 &&
        _phone.text.trim().length >= 10 &&
        _email.text.contains('@') &&
        _city != null &&
        _district != null &&
        _vehicle != null &&
        _model != null &&
        _company != null &&
        _start != null &&
        (!_needsCompanyName || _companyName.text.trim().isNotEmpty);
    if (!filled) {
      setState(() => _err = l.applyMissing);
      return;
    }
    if (_consents.any((c) => !c.settled)) {
      setState(() => _err = l.applyConsentsMissing);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (!await panel.checkApplicationPhone(_phone.text.trim())) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _err = l.applyPhoneUsed;
        });
        return;
      }
      final number = await panel.submitApplication({
        'fullName': name,
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'cityId': _city!.id,
        'districtId': _district!.id,
        'vehicleType': _vehicle,
        'workModel': _model,
        'companyStatus': _company,
        if (_needsCompanyName) 'companyName': _companyName.text.trim(),
        'availability': _start,
        'sourceChannel': 'PUBLIC_LINK',
        'consents': [for (final c in _consents) c.toJson()],
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _doneNumber = number;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = _apiError(
          l,
          e,
          (code, message) => code == 'APPLICATION_ALREADY_EXISTS'
              ? l.applyPhoneUsed
              : message ?? l.availabilityFailed,
        );
      });
    }
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
            _err = null;
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

  Widget _field(
    TextEditingController c,
    String hint, {
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final panel = ref.read(sessionProvider).panel!;
    final done = _doneNumber;
    if (done != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.applyTitle)),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DgIcon(LucideIcons.circleCheck, size: 48, color: Dg.sage),
              const SizedBox(height: 16),
              Text(
                l.applySent(done),
                textAlign: TextAlign.center,
                style: Dg.ui(size: 17, weight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              DgButton(
                label: l.joinClose,
                tone: DgButtonTone.secondary,
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.applyTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                _field(_name, l.applyName),
                _field(_phone, l.applyPhone, keyboard: TextInputType.phone),
                _field(
                  _email,
                  l.applyEmail,
                  keyboard: TextInputType.emailAddress,
                ),
                _label(l.applyWhere),
                Row(
                  children: [
                    Expanded(
                      child: DgButton(
                        label: _city?.name ?? l.editCity,
                        tone: DgButtonTone.secondary,
                        onPressed: () async {
                          final c = await pickPlace(
                            context,
                            l.editCity,
                            panel.fetchCities,
                          );
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
                                final d = await pickPlace(
                                  context,
                                  l.editDistrict,
                                  () => panel.fetchDistricts(_city!.id),
                                );
                                if (d != null) setState(() => _district = d);
                              },
                      ),
                    ),
                  ],
                ),
                _label(l.editVehicle),
                _chips(_vehicles, _vehicle, l.vehicle, (c) => _vehicle = c),
                _label(l.editWork),
                _chips(_models, _model, l.workModel, (c) => _model = c),
                _label(l.editCompany),
                _chips(
                  _companies,
                  _company,
                  l.companyStatus,
                  (c) => _company = c,
                ),
                if (_needsCompanyName)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _companyName,
                      decoration: InputDecoration(hintText: l.editCompanyName),
                    ),
                  ),
                _label(l.applyWhen),
                _chips(_starts, _start, l.startWhen, (c) => _start = c),
                if (_consents.isNotEmpty) _label(l.applyConsents),
                for (final c in _consents)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DgCard(
                      onTap: () => _read(c),
                      child: Row(
                        children: [
                          DgSelectMark(selected: c.positive),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c.def['title'] ?? c.def['name'] ?? c.def['code'] ?? ''}',
                                  style: Dg.ui(
                                    size: 15,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                if (c.required)
                                  Text(
                                    l.applyConsentRequired,
                                    style: Dg.ui(size: 12, color: Dg.mid),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            l.applyConsentOpen,
                            style: Dg.ui(
                              size: 14,
                              weight: FontWeight.w700,
                              color: Dg.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _error(_err),
              ],
            ),
          ),
          Material(
            color: Dg.surface,
            elevation: 8,
            shadowColor: const Color(0x1412191A),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: DgButton(
                  label: l.applySend,
                  trailing: LucideIcons.send,
                  busy: _busy,
                  onPressed: _send,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onay metni: sonuna kadar okunmadan karar düğmeleri açılmaz.
class _ConsentReader extends StatefulWidget {
  const _ConsentReader({required this.consent});

  final _Consent consent;

  @override
  State<_ConsentReader> createState() => _ConsentReaderState();
}

class _ConsentReaderState extends State<_ConsentReader> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _check() {
    if (widget.consent.scrolledAt != null || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 24) {
      setState(() => widget.consent.scrolledAt = DateTime.now());
    }
  }

  void _decide(String decision) {
    widget.consent
      ..decision = decision
      ..decidedAt = DateTime.now();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = widget.consent;
    final read = c.scrolledAt != null;
    final yes = c.mode == 'ACKNOWLEDGEMENT' ? 'ACKNOWLEDGED' : 'ACCEPTED';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${c.def['title'] ?? c.def['name'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                '${c.def['content'] ?? ''}',
                style: Dg.ui(size: 15, color: Dg.ink2),
              ),
            ),
          ),
          Material(
            color: Dg.surface,
            elevation: 8,
            shadowColor: const Color(0x1412191A),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    if (!read)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l.consentScrollFirst,
                          style: Dg.ui(size: 14, color: Dg.ink3),
                        ),
                      ),
                    DgButton(
                      label: c.mode == 'ACKNOWLEDGEMENT'
                          ? l.consentAck
                          : l.consentAccept,
                      icon: LucideIcons.check,
                      onPressed: read ? () => _decide(yes) : null,
                    ),
                    if (c.mode != 'ACKNOWLEDGEMENT' && c.mode != 'ACCEPTANCE')
                      TextButton(
                        onPressed: read ? () => _decide('DECLINED') : null,
                        child: Text(l.consentDecline),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// E-postadaki bağlantıyla aday evraklarını yükleme.
class DocumentPortalScreen extends ConsumerStatefulWidget {
  const DocumentPortalScreen({super.key});

  @override
  ConsumerState<DocumentPortalScreen> createState() =>
      _DocumentPortalScreenState();
}

class _DocumentPortalScreenState extends ConsumerState<DocumentPortalScreen> {
  final _link = TextEditingController();
  String? _publicId;
  String? _token;
  Map<String, dynamic>? _portal;
  bool _busy = false;
  String? _uploading;
  String? _err;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final l = context.l10n;
    final parsed = parseJoinLink(_link.text);
    if (parsed.token == null || parsed.publicId == null) {
      setState(() => _err = l.linkBad);
      return;
    }
    _publicId = parsed.publicId;
    _token = parsed.token;
    setState(() {
      _busy = true;
      _err = null;
    });
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reload() async {
    final l = context.l10n;
    try {
      final portal = await ref
          .read(sessionProvider)
          .panel!
          .fetchDocumentPortal(publicId: _publicId!, token: _token!);
      if (mounted) setState(() => _portal = portal);
    } catch (e) {
      if (mounted) setState(() => _err = _apiError(l, e, l.joinLinkError));
    }
  }

  Future<void> _upload(Map doc, String side) async {
    final l = context.l10n;
    final definition = doc['definition'] as Map? ?? const {};
    String? expiry;
    if (definition['requiresExpiryDate'] == true) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        helpText: l.docExpiry,
        initialDate: now.add(const Duration(days: 365)),
        firstDate: now,
        lastDate: DateTime(now.year + 30),
      );
      if (picked == null) return;
      String two(int n) => n.toString().padLeft(2, '0');
      expiry = '${picked.year}-${two(picked.month)}-${two(picked.day)}';
    }
    final path = await capturePhoto();
    if (path == null || !mounted) return;
    final key = '${doc['id']}:$side';
    setState(() {
      _uploading = key;
      _err = null;
    });
    try {
      final bytes = path.startsWith('test://')
          ? const <int>[1]
          : await File(path).readAsBytes();
      await ref
          .read(sessionProvider)
          .panel!
          .uploadPortalDocument(
            publicId: _publicId!,
            token: _token!,
            documentRequestId: '${doc['id']}',
            side: side,
            bytes: bytes,
            expiresAt: expiry,
          );
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _err = _apiError(l, e, l.docsError));
    }
    if (mounted) setState(() => _uploading = null);
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref
          .read(sessionProvider)
          .panel!
          .submitPortalDocuments(publicId: _publicId!, token: _token!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = _apiError(l, e, l.docsError);
      });
      return;
    }
    if (!mounted) return;
    _snack(context, l.docsSent);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final portal = _portal;
    if (portal == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.joinDocs)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              controller: _link,
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              decoration: InputDecoration(hintText: l.linkHint),
            ),
            _error(_err),
            const SizedBox(height: 16),
            DgButton(label: l.linkContinue, busy: _busy, onPressed: _open),
          ],
        ),
      );
    }
    final docs = [
      for (final d
          in (portal['documentPackage'] as Map?)?['documents'] as List? ??
              const [])
        if (d is Map) d,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.docsTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                for (final d in docs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DgCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${d['titleTr'] ?? ''}',
                                  style: Dg.ui(
                                    size: 16,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (d['isRequired'] == true)
                                Text(
                                  l.applyConsentRequired,
                                  style: Dg.ui(size: 12, color: Dg.mid),
                                ),
                            ],
                          ),
                          if ('${d['instructionsTr'] ?? ''}'.isNotEmpty)
                            Text(
                              '${d['instructionsTr']}',
                              style: Dg.ui(size: 14, color: Dg.ink2),
                            ),
                          if ('${d['revisionReason'] ?? ''}'.isNotEmpty)
                            Text(
                              '${d['revisionReason']}',
                              style: Dg.ui(size: 14, color: Dg.hi),
                            ),
                          const SizedBox(height: 8),
                          for (final part in _parts(d))
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${l.docSide(part.side)} · ${l.docStatus(part.status)}',
                                      style: Dg.ui(size: 14, color: Dg.ink2),
                                    ),
                                  ),
                                  if (part.status != 'APPROVED')
                                    DgButton(
                                      label: part.hasFile
                                          ? l.docRetake
                                          : l.docTake,
                                      icon: LucideIcons.camera,
                                      tone: DgButtonTone.secondary,
                                      expand: false,
                                      height: 44,
                                      busy:
                                          _uploading ==
                                          '${d['id']}:${part.side}',
                                      onPressed: _uploading == null
                                          ? () => _upload(d, part.side)
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                _error(_err),
              ],
            ),
          ),
          Material(
            color: Dg.surface,
            elevation: 8,
            shadowColor: const Color(0x1412191A),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: DgButton(
                  label: l.docsSend,
                  trailing: LucideIcons.send,
                  busy: _busy,
                  onPressed: _submit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ön/arka yüzlü belgede iki satır, tek dosyalı belgede bir satır.
  List<({String side, String status, bool hasFile})> _parts(Map d) {
    final parts = [
      for (final p in d['parts'] as List? ?? const [])
        if (p is Map)
          (
            side: '${p['side'] ?? 'SINGLE'}',
            status: '${p['status'] ?? ''}',
            hasFile: p['currentFile'] != null,
          ),
    ];
    if (parts.isNotEmpty) return parts;
    final frontBack = (d['definition'] as Map?)?['captureMode'] == 'FRONT_BACK';
    return [
      for (final side in frontBack ? ['FRONT', 'BACK'] : ['SINGLE'])
        (
          side: side,
          status: '${d['status'] ?? ''}',
          hasFile: d['currentFile'] != null,
        ),
    ];
  }
}
