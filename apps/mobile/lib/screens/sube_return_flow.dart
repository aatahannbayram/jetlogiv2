import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../motion.dart';
import '../scan.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Kurye Dönüş (mockup 5): kurye seç → dönen gönderileri okut → sonucu
/// kontrol et → tamamla. Her okutma kuyruğa yazılır ve sırayla sunucuya
/// gider; sunucu teyidi gelmeden "teslim alındı" sayılmaz.
class SubeReturnFlow extends ConsumerStatefulWidget {
  const SubeReturnFlow({super.key});

  @override
  ConsumerState<SubeReturnFlow> createState() => _SubeReturnFlowState();
}

typedef _Scan = ({String code, ScanOutcome outcome});

class _SubeReturnFlowState extends ConsumerState<SubeReturnFlow> {
  int _step = 0;

  /// Seçilen kurye adı; null = kurye seçmeden okutma.
  String? _courier;
  final _scans = <_Scan>[];
  bool _busy = false;
  bool _finishing = false;
  int? _doneCount;

  List<PendingItem> _expected(PendingData? pending) => [
    for (final item in pending?.returns ?? const <PendingItem>[])
      if (_courier == null || item.courierName == _courier) item,
  ];

  Future<void> _onCode(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await ref
        .read(sessionProvider)
        .branch
        .scan(ScanContext.courierReturn, code);
    await playScanFeedback(beep: outcome.ok);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _scans.insert(0, (code: code.trim(), outcome: outcome));
    });
  }

  Future<void> _finish() async {
    final l = context.l10n;
    final branch = ref.read(sessionProvider).branch;
    setState(() => _finishing = true);
    await branch.flush();
    if (!mounted) return;
    final queued = branch.pendingScans;
    setState(() {
      _finishing = false;
      _doneCount = _scans.where((s) => s.outcome.ok).length;
    });
    if (queued > 0) subeSnack(context, l.returnQueued(queued));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final expected = _expected(branch.pending);
    return Scaffold(
      appBar: AppBar(title: Text(l.courierReturnTitle)),
      body: SafeArea(
        top: false,
        child: _doneCount != null
            ? _Done(count: _doneCount!, onClose: () => Navigator.pop(context))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: DgStepper(
                      steps: [
                        l.returnStepCourier,
                        l.returnStepScan,
                        l.returnStepCheck,
                      ],
                      current: _step,
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: DgMotion.standard,
                      switchInCurve: DgMotion.enter,
                      switchOutCurve: DgMotion.exit,
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: switch (_step) {
                          0 => _CourierStep(
                            pending: branch.pending,
                            couriers:
                                branch.dashboard?.courierList ??
                                const <BranchCourierLive>[],
                            onPick: (name) => setState(() {
                              _courier = name;
                              _step = 1;
                            }),
                          ),
                          1 => _ScanStep(
                            courier: _courier,
                            expected: expected.length,
                            scans: _scans,
                            busy: _busy,
                            onCode: _onCode,
                          ),
                          _ => _CheckStep(expected: expected, scans: _scans),
                        },
                      ),
                    ),
                  ),
                  if (_step > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          IconButton.outlined(
                            tooltip: l.back,
                            onPressed: _finishing
                                ? null
                                : () => setState(() => _step--),
                            icon: const Icon(LucideIcons.arrowLeft, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _step == 1
                                ? DgGradientButton(
                                    key: const Key('return-review'),
                                    label: l.continueLabel,
                                    trailing: LucideIcons.arrowRight,
                                    onPressed: _scans.isEmpty || _busy
                                        ? null
                                        : () => setState(() => _step = 2),
                                  )
                                : DgGradientButton(
                                    key: const Key('return-complete'),
                                    label: l.returnComplete,
                                    icon: LucideIcons.check,
                                    busy: _finishing,
                                    onPressed: _finishing ? null : _finish,
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
}

/// 1. adım: dönüş bekleyen kuryeler (bekleyen dönüş adediyle), ardından
/// üzerinde paket olan diğer kuryeler.
class _CourierStep extends StatelessWidget {
  const _CourierStep({
    required this.pending,
    required this.couriers,
    required this.onPick,
  });

  final PendingData? pending;
  final List<BranchCourierLive> couriers;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final waiting = <String, int>{};
    for (final item in pending?.returns ?? const <PendingItem>[]) {
      if (item.courierName.isEmpty) continue;
      waiting[item.courierName] = (waiting[item.courierName] ?? 0) + 1;
    }
    final others = [
      for (final c in couriers)
        if (!waiting.containsKey(c.name) && c.holdingCount > 0) c,
    ];
    final entries = [
      for (final e in waiting.entries)
        (name: e.key, line: l.returnExpected(e.value), hot: true),
      for (final c in others)
        (name: c.name, line: l.holdingCount(c.holdingCount), hot: false),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          l.returnPickCourier,
          style: Dg.ui(size: 17, weight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < entries.length; i++)
          StaggerIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgPanel(
                onTap: () => onPick(entries[i].name),
                child: Row(
                  children: [
                    InitialsAvatar(name: entries[i].name, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entries[i].name,
                            style: Dg.ui(size: 16, weight: FontWeight.w600),
                          ),
                          Text(
                            entries[i].line,
                            style: Dg.ui(
                              size: 13,
                              color: entries[i].hot ? Dg.warn : Dg.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => onPick(null),
          icon: const Icon(LucideIcons.scanLine, size: 18),
          label: Text(l.returnAnyCourier),
        ),
      ],
    );
  }
}

/// 2. adım: kamera / elle giriş; her okutmada nabız ve sonuç satırı.
class _ScanStep extends StatelessWidget {
  const _ScanStep({
    required this.courier,
    required this.expected,
    required this.scans,
    required this.busy,
    required this.onCode,
  });

  final String? courier;
  final int expected;
  final List<_Scan> scans;
  final bool busy;
  final ValueChanged<String> onCode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ok = scans.where((s) => s.outcome.ok).length;
    final last = scans.firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courier ?? l.returnAnyCourier,
                    style: Dg.ui(size: 17, weight: FontWeight.w700),
                  ),
                  Text(
                    l.returnScanHint,
                    style: Dg.ui(size: 13, color: Dg.text3),
                  ),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                ScanPulse(
                  trigger: last == null ? null : scans.length,
                  tone: switch (last?.outcome.tone) {
                    ScanTone.ok => FeedbackTone.ok,
                    ScanTone.warn => FeedbackTone.warn,
                    _ => FeedbackTone.bad,
                  },
                  size: 64,
                ),
                Text(
                  expected > 0 ? '$ok/$expected' : '$ok',
                  style: Dg.stat(size: 18, weight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        BarcodeScanPane(onDetect: onCode),
        if (busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 8),
        for (final s in scans.take(8))
          ScanOutcomeTile(code: s.code, outcome: s.outcome),
      ],
    );
  }
}

/// 3. adım: beklenen / okunan özeti ve sonuç grupları.
class _CheckStep extends StatelessWidget {
  const _CheckStep({required this.expected, required this.scans});

  final List<PendingItem> expected;
  final List<_Scan> scans;

  static String _norm(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ok = [
      for (final s in scans)
        if (s.outcome.tone == ScanTone.ok) s,
    ];
    final queued = [
      for (final s in scans)
        if (s.outcome.tone == ScanTone.warn) s,
    ];
    final bad = [
      for (final s in scans)
        if (s.outcome.tone == ScanTone.bad) s,
    ];
    final scanned = {for (final s in scans) _norm(s.code)};
    final missing = [
      for (final item in expected)
        if (!scanned.contains(_norm(item.shipmentNumber))) item,
    ];
    Widget group(String title, DgTone tone, List<Widget> rows) => rows.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DgPanel(
              title: '$title (${rows.length})',
              trailing: DgStatusPill(
                label: '${rows.length}',
                tone: tone,
                dense: true,
              ),
              child: Column(children: rows),
            ),
          );
    Widget line(String code, String detail) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(code, style: Dg.ui(size: 14, weight: FontWeight.w600)),
          ),
          if (detail.isNotEmpty)
            Flexible(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Dg.ui(size: 13, color: Dg.text3),
              ),
            ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        DgCountSummary(
          expected: expected.length,
          read: ok.length,
          missing: expected.isEmpty ? null : missing.length,
        ),
        const SizedBox(height: 12),
        if (scans.isEmpty)
          DgEmptyState(icon: LucideIcons.scanLine, title: l.returnNothing),
        group(l.returnGroupOk, DgTone.ok, [
          for (final s in ok) line(s.code, s.outcome.detail),
        ]),
        group(l.returnGroupQueued, DgTone.warn, [
          for (final s in queued) line(s.code, s.outcome.title),
        ]),
        group(l.returnGroupBad, DgTone.bad, [
          for (final s in bad) line(s.code, s.outcome.title),
        ]),
        group(l.returnGroupMissing, DgTone.neutral, [
          for (final m in missing) line(m.shipmentNumber, m.recipientName),
        ]),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.count, required this.onClose});

  final int count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DoneRing(icon: LucideIcons.check),
          const SizedBox(height: 20),
          Text(
            l.returnDone(count),
            textAlign: TextAlign.center,
            style: Dg.ui(size: 20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 28),
          DgGradientButton(label: l.done, onPressed: onClose),
        ],
      ),
    );
  }
}
