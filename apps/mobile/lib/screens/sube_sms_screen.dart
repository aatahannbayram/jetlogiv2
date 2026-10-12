import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Şablonla SMS: gönderi alıcılarına ya da kuryelere. Telefonlar maskeli
/// gelir; metni backend şablondan üretir, önizleme gönderimden önce görünür.
class SubeSmsScreen extends ConsumerStatefulWidget {
  const SubeSmsScreen({super.key});

  @override
  ConsumerState<SubeSmsScreen> createState() => _SubeSmsScreenState();
}

class _SubeSmsScreenState extends ConsumerState<SubeSmsScreen> {
  final _search = TextEditingController();
  final _picked = <String>{};
  final _variables = <String, TextEditingController>{};
  String? _templateKey;
  int _type = 0;
  List<SmsTarget> _targets = const [];
  String? _targetError;
  SmsPreview? _preview;
  bool _busy = false;

  String get _targetType => _type == 0 ? 'SHIPMENTS' : 'COURIERS';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(sessionProvider).branch.loadSmsTemplates();
      await _loadTargets();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    for (final c in _variables.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final branch = ref.read(sessionProvider).branch;
    try {
      final next = await branch.smsTargets(_targetType, query: _search.text);
      if (!mounted) return;
      setState(() {
        _targets = next;
        _targetError = null;
        _picked.removeWhere((id) => !next.any((t) => t.id == id));
        _preview = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _targetError = BranchWorkspace.describeError(e));
    }
  }

  Map<String, String> get _values => {
    for (final e in _variables.entries)
      if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
  };

  Future<void> _doPreview(BranchWorkspace branch, SmsTemplate template) async {
    setState(() => _busy = true);
    try {
      final preview = await branch.previewSms(
        targetType: _targetType,
        targetIds: _picked.toList(),
        template: template,
        variables: _values,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        // Backend'in istediği eksik değişkenler için alan aç.
        for (final name in preview.missingVariables) {
          _variables.putIfAbsent(name, TextEditingController.new);
        }
      });
    } catch (e) {
      if (mounted) subeSnack(context, BranchWorkspace.describeError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _send(BranchWorkspace branch, SmsTemplate template) async {
    final l = context.l10n;
    setState(() => _busy = true);
    final error = await branch.sendSms(
      targetType: _targetType,
      targetIds: _picked.toList(),
      template: template,
      variables: _values,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) {
        _picked.clear();
        _preview = null;
      }
    });
    subeSnack(context, error ?? l.smsQueued);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final templates = branch.smsTemplates;
    final template = templates == null || templates.isEmpty
        ? null
        : templates.firstWhere(
            (t) => t.key == _templateKey,
            orElse: () => templates.first,
          );
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeSmsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubeStatusBanner(branch: branch, onRetry: branch.loadSmsTemplates),
          if (templates == null)
            if (branch.loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              const SizedBox.shrink()
          else if (!branch.capabilities.operate)
            Text(l.noPermission, style: Dg.ui(size: 13, color: Dg.ink3))
          else if (template == null)
            DgEmptyState(
              icon: LucideIcons.messageSquare,
              title: l.smsNoTemplates,
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: template.key,
              decoration: InputDecoration(labelText: l.smsTemplate),
              items: [
                for (final t in templates)
                  DropdownMenuItem(value: t.key, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() {
                _templateKey = v;
                _preview = null;
              }),
            ),
            const SizedBox(height: 8),
            Text(template.body, style: Dg.ui(size: 13, color: Dg.ink2)),
            const SizedBox(height: 12),
            SegmentedTabs(
              labels: [l.smsToRecipients, l.smsToCouriers],
              index: _type,
              onChanged: (i) {
                setState(() {
                  _type = i;
                  _picked.clear();
                });
                _loadTargets();
              },
            ),
            if (_type == 0) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(hintText: l.smsSearchHint),
                onSubmitted: (_) => _loadTargets(),
              ),
            ],
            const SizedBox(height: 8),
            if (_targetError != null)
              Text(_targetError!, style: Dg.ui(size: 13, color: Dg.hi)),
            for (final t in _targets)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _picked.contains(t.id),
                onChanged: !t.hasPhone
                    ? null
                    : (v) => setState(() {
                        v == true ? _picked.add(t.id) : _picked.remove(t.id);
                        _preview = null;
                      }),
                title: Text(t.title, style: Dg.ui(size: 14)),
                subtitle: Text(
                  t.hasPhone ? t.subtitle : l.smsNoPhone,
                  style: Dg.ui(size: 12, color: Dg.ink3),
                ),
              ),
            for (final e in _variables.entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: e.value,
                  decoration: InputDecoration(labelText: e.key),
                ),
              ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              DgCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.rendered ?? preview.missingVariables.join(', '),
                      style: Dg.ui(
                        size: 14,
                        color: preview.rendered == null ? Dg.hi : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.smsReach(
                        preview.reachableCount,
                        preview.recipientCount,
                      ),
                      style: Dg.ui(size: 12, color: Dg.ink3),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            DgButton(
              label: l.smsPreview,
              tone: DgButtonTone.secondary,
              busy: _busy,
              onPressed: _picked.isEmpty
                  ? null
                  : () => _doPreview(branch, template),
            ),
            const SizedBox(height: 8),
            // Metni görmeden gönderim yok.
            DgButton(
              label: l.smsSendN(_picked.length),
              icon: LucideIcons.send,
              busy: _busy,
              onPressed: preview?.rendered == null || _picked.isEmpty
                  ? null
                  : () => _send(branch, template),
            ),
          ],
        ],
      ),
    );
  }
}
