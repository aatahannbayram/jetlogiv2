import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/panel_models.dart';
import '../l10n.dart';
import '../motion.dart';
import '../privacy.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

Widget _errorText(String? error) => error == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ShakeError(
          trigger: error,
          child: Text(
            error,
            style: TextStyle(
              color: Dg.hi,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Yeni şifre sunucunun kuralına uyuyor mu: 10–128 karakter; büyük harf,
/// küçük harf, rakam ve özel karakter.
bool passwordStrongEnough(String p) =>
    p.length >= 10 &&
    p.length <= 128 &&
    p.contains(RegExp(r'[A-ZÇĞİÖŞÜ]')) &&
    p.contains(RegExp(r'[a-zçğıöşü]')) &&
    p.contains(RegExp(r'\d')) &&
    p.contains(RegExp(r'[^A-Za-z0-9ÇĞİÖŞÜçğıöşü]'));

class PasswordScreen extends ConsumerStatefulWidget {
  const PasswordScreen({super.key});

  @override
  ConsumerState<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends ConsumerState<PasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_next.text != _again.text) {
      setState(() => _error = l.passwordMismatch);
      return;
    }
    if (!passwordStrongEnough(_next.text)) {
      setState(() => _error = l.passwordWeak);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider)
          .changePanelPassword(current: _current.text, next: _next.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is PanelApiException
            ? e.statusCode == null
                  ? l.visitOffline
                  : l.passwordError(e.code, e.serverMessage)
            : l.passwordError('', null);
      });
      return;
    }
    if (!mounted) return;
    _snack(context, l.passwordChanged);
    Navigator.of(context).pop();
  }

  Widget _field(TextEditingController c, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Şifre yazılırken ekran görüntüsü ve kayıt kapalı.
    return PrivacyGate(
      active: true,
      child: Scaffold(
        appBar: AppBar(title: Text(l.passwordTitle)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _field(_current, l.passwordCurrent),
            _field(_next, l.passwordNew),
            _field(_again, l.passwordAgain),
            Text(l.passwordRules, style: Dg.ui(size: 14, color: Dg.ink2)),
            _errorText(_error),
            const SizedBox(height: 16),
            DgButton(
              label: l.passwordSave,
              icon: LucideIcons.keyRound,
              busy: _busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Haftalık müsaitlik: her gün için aç/kapa ve bir saat aralığı.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  /// Pazartesiden başlayan gösterim sırası (sunucuda 0 = Pazar).
  static const _order = [1, 2, 3, 4, 5, 6, 0];

  AvailabilityDto? _plan;
  bool _failed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final plan = await ref.read(sessionProvider).loadAvailability();
      if (mounted) {
        setState(() {
          _plan = plan;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _update(AvailabilityDay day) {
    final plan = _plan!;
    setState(() {
      _error = null;
      _plan = AvailabilityDto(
        days: [for (final d in plan.days) d.dayIndex == day.dayIndex ? day : d],
        exceptions: plan.exceptions,
      );
    });
  }

  void _toggle(AvailabilityDay d) => _update(
    d.copyWith(
      enabled: !d.enabled,
      ranges: !d.enabled && d.ranges.isEmpty
          ? const [(start: '09:00', end: '18:00')]
          : null,
    ),
  );

  Future<void> _pick(AvailabilityDay d, {required bool start}) async {
    final first = d.ranges.first;
    final parts = (start ? first.start : first.end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    final value = '${two(picked.hour)}:${two(picked.minute)}';
    _update(
      d.copyWith(
        ranges: [
          start
              ? (start: value, end: first.end)
              : (start: first.start, end: value),
          ...d.ranges.skip(1),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final l = context.l10n;
    final plan = _plan;
    if (plan == null) return;
    for (final d in plan.days) {
      if (!d.enabled) continue;
      if (d.ranges.any((r) => r.end.compareTo(r.start) <= 0)) {
        setState(() => _error = l.availabilityBadRange);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider).saveAvailability(plan);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is PanelApiException && e.statusCode == null
            ? l.visitOffline
            : (e is PanelApiException ? e.serverMessage : null) ??
                  l.availabilityFailed;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(context, l.availabilitySaved);
  }

  Widget _time(String value, VoidCallback onTap) => Material(
    color: Dg.elev,
    borderRadius: BorderRadius.circular(Dg.radius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dg.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Mono(value, size: 15, weight: FontWeight.w700),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: Text(l.availabilityTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                if (_failed)
                  DgRetryBanner(
                    message: l.reportFailedLoad,
                    onRetry: _load,
                    retryLabel: l.retryNow,
                  )
                else if (plan == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l.availabilityHint,
                      style: Dg.ui(size: 15, color: Dg.ink2),
                    ),
                  ),
                  for (final i in _order)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _dayCard(l, plan.days[i]),
                    ),
                  _errorText(_error),
                ],
              ],
            ),
          ),
          if (plan != null)
            Material(
              color: Dg.surface,
              elevation: 8,
              shadowColor: const Color(0x1412191A),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: DgButton(
                    label: l.availabilitySave,
                    icon: LucideIcons.check,
                    busy: _busy,
                    onPressed: _save,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCard(L10n l, AvailabilityDay d) {
    final on = d.enabled && d.ranges.isNotEmpty;
    return DgCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.weekday(d.dayIndex),
                  style: Dg.ui(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (on)
                  Row(
                    children: [
                      _time(d.ranges.first.start, () => _pick(d, start: true)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('–', style: Dg.ui(size: 15)),
                      ),
                      _time(d.ranges.first.end, () => _pick(d, start: false)),
                    ],
                  )
                else
                  Text(
                    l.availabilityOff,
                    style: Dg.ui(size: 14, color: Dg.ink3),
                  ),
              ],
            ),
          ),
          DgSwitch(value: on, onChanged: (_) => _toggle(d)),
        ],
      ),
    );
  }
}
