import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/panel_models.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../signature.dart';
import '../theme.dart';
import '../widgets.dart';

/// Dijital tutanak: tür, açıklama ve iki imza (kurye + karşı taraf).
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const _types = ['DELIVERY', 'PICKUP', 'DAMAGE', 'OTHER'];

  String _type = 'DELIVERY';
  final _note = TextEditingController();
  final _name = TextEditingController();
  SignatureCapture? _mine;
  SignatureCapture? _theirs;
  bool _busy = false;
  String? _error;
  List<TaskReportDto> _past = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPast());
  }

  @override
  void dispose() {
    _note.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadPast() async {
    try {
      final rows = await ref.read(sessionProvider).taskReports(widget.taskId);
      if (mounted) setState(() => _past = rows);
    } catch (_) {}
  }

  bool _signed(SignatureCapture? s) => s != null && !s.isEmpty;

  Future<void> _send() async {
    final l = context.l10n;
    final s = ref.read(sessionProvider);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = l.reportNeedName);
      return;
    }
    if (!_signed(_mine) || !_signed(_theirs)) {
      setState(() => _error = l.reportNeedSigns);
      return;
    }
    if (!s.online) {
      setState(() => _error = l.visitOffline);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await s.createTaskReport(
        widget.taskId,
        reportType: _type,
        courierSignature: _mine!,
        counterpartSignature: _theirs!,
        counterpartName: _name.text.trim(),
        note: _note.text.trim(),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.reportFailed;
        });
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.reportSent)));
    Navigator.of(context).pop();
  }

  static String _when(DateTime? at) {
    if (at == null) return '';
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: Dg.ui(size: 14, weight: FontWeight.w600, color: Dg.ink2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final task = s.taskOrNull(widget.taskId);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reportNew),
            if (task != null)
              Text(
                task.recipient,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Dg.ink3,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _types)
                      DgChoiceSurface(
                        selected: _type == t,
                        onTap: () => setState(() => _type = t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            l.reportType(t),
                            style: Dg.ui(size: 15, weight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: InputDecoration(hintText: l.reportNoteHint),
                ),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: l.reportOtherName),
                ),
                _label(l.reportOtherSign),
                SignaturePad(
                  hint: l.signHere,
                  onChanged: (c) => setState(() => _theirs = c),
                ),
                _label(l.reportYourSign),
                SignaturePad(
                  hint: l.signHere,
                  onChanged: (c) => setState(() => _mine = c),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ShakeError(
                      trigger: _error,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Dg.hi,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                if (_past.isNotEmpty) ...[
                  _label(l.reportPast),
                  for (final r in _past)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DgCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                l.reportType(r.reportType),
                                _when(r.createdAt),
                              ].where((e) => e.isNotEmpty).join(' · '),
                              style: Dg.ui(size: 15, weight: FontWeight.w700),
                            ),
                            if ((r.note ?? '').isNotEmpty)
                              Text(
                                r.note!,
                                style: Dg.ui(size: 14, color: Dg.ink2),
                              ),
                            if (r.counterpartName.isNotEmpty)
                              Text(
                                r.counterpartName,
                                style: Dg.ui(size: 13, color: Dg.ink3),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
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
                  label: l.reportSend,
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
