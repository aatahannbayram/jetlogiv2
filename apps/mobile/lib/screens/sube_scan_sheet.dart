import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../scan.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Seri okutma: sayfa kapanmadan art arda okutulur, her kod [scanContext]'in
/// işlemine gider ve sonucu hemen altta görünür.
Future<void> showSubeScanSheet(
  BuildContext context, {
  required ScanContext scanContext,
  required String hint,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Dg.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SubeScanSheet(scanContext: scanContext, hint: hint),
  );
}

class _SubeScanSheet extends ConsumerStatefulWidget {
  const _SubeScanSheet({required this.scanContext, required this.hint});

  final ScanContext scanContext;
  final String hint;

  @override
  ConsumerState<_SubeScanSheet> createState() => _SubeScanSheetState();
}

class _SubeScanSheetState extends ConsumerState<_SubeScanSheet> {
  final _seen = <({String code, ScanOutcome outcome})>[];
  bool _busy = false;

  Future<void> _onCode(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await ref
        .read(sessionProvider)
        .branch
        .scan(widget.scanContext, code);
    await playScanFeedback(beep: outcome.ok);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _seen.insert(0, (code: code.trim(), outcome: outcome));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accepted = _seen.where((s) => s.outcome.ok).length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.scanAction,
                  style: Dg.ui(size: 17, weight: FontWeight.w700),
                ),
              ),
              if (_seen.isNotEmpty) Mono('$accepted / ${_seen.length}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.hint, style: Dg.ui(size: 13, color: Dg.ink2)),
          const SizedBox(height: 12),
          BarcodeScanPane(onDetect: _onCode),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in _seen.take(8))
                  ScanOutcomeTile(code: s.code, outcome: s.outcome),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DgButton(
            label: l.scanDone,
            tone: DgButtonTone.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
