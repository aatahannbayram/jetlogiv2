import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/models.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final subject = TextEditingController();
  final body = TextEditingController();
  String category = 'OTHER';
  bool sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).loadTickets();
    });
  }

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = subject.text.trim();
    final b = body.text.trim();
    if (s.isEmpty || b.isEmpty || sending) return;
    setState(() => sending = true);
    final session = ref.read(sessionProvider);
    final tid = session.nextStop?.id;
    session.createSupportTicket(
      category: category,
      subject: s,
      body: b,
      taskId: tid != null && tid.contains('-') ? tid : null,
    );
    subject.clear();
    body.clear();
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.support)),
      body: RefreshIndicator(
        onRefresh: () => session.loadTickets(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            DgCard(
              onTap: () => dialNumber(context, '112'),
              child: Row(
                children: [
                  DgIcon(LucideIcons.siren, color: Dg.bad, weight: 600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.sos, style: Dg.ui(size: 16, weight: FontWeight.w700)),
                        Text(l.sosHint, style: Dg.ui(size: 13, color: Dg.ink2)),
                      ],
                    ),
                  ),
                  Text(l.sosCall, style: Dg.ui(size: 13, weight: FontWeight.w700, color: Dg.red)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Display(l.openTicket, size: 22),
            const SizedBox(height: 12),
            DgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Mono(l.categoryCaps, size: 11, color: Dg.ink3),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in supportCategories)
                        GestureDetector(
                          onTap: () => setState(() => category = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: category == c
                                  ? Dg.primaryGradientStart
                                  : Dg.elev,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l.categoryOf(c),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: category == c ? Colors.white : Dg.ink2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    controller: subject,
                    decoration: InputDecoration(
                      hintText: l.subject,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: l.whatHappened,
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DgButton(
                    label: l.send,
                    icon: LucideIcons.send,
                    busy: sending,
                    onPressed: sending ? null : _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Display(l.myRecords, size: 22),
            const SizedBox(height: 12),
            if (session.tickets.isEmpty)
              DgEmptyState(
                icon: LucideIcons.lifeBuoy,
                title: l.noTickets,
                body: l.ticketsEmptyBody,
              )
            else
              for (final t in session.tickets) ...[
                DgCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.subject,
                              style: Dg.ui(size: 16, weight: FontWeight.w700),
                            ),
                          ),
                          StatusChip(label: t.statusLabel, tone: 'mid'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Mono(
                        '${t.reference} · ${l.categoryOf(t.category)}',
                        size: 12,
                        color: Dg.ink3,
                      ),
                      if (t.body.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(t.body, style: Dg.ui(size: 14, color: Dg.ink2)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}
