import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'task_detail_screen.dart';

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key});

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  int tab = 0;
  final query = TextEditingController();

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  String _emptyMessage(int tab) => switch (tab) {
    0 => 'Bekleyen görev yok — hepsi tamam.',
    1 => 'Henüz teslimat yapılmadı.',
    _ => 'İade kaydı yok.',
  };

  IconData _emptyIcon(int tab) => switch (tab) {
    0 => Icons.check_circle_outline_rounded,
    1 => Icons.local_shipping_outlined,
    _ => Icons.assignment_return_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final bekleyen = s.tasks.where((t) => t.status != TaskStatus.delivered && t.status != TaskStatus.failed).toList();
    final teslim = s.tasks.where((t) => t.status == TaskStatus.delivered).toList();
    final iade = s.tasks.where((t) => t.status == TaskStatus.failed).toList();
    final source = switch (tab) { 0 => bekleyen, 1 => teslim, _ => iade };
    final q = query.text.trim().toLowerCase();
    final rows = q.isEmpty ? source : source.where((t) => t.recipient.toLowerCase().contains(q)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Display('Dağıtım', size: 26),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Dg.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: Dg.rule)),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 17, color: Dg.ink3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: query,
                        onChanged: (_) => setState(() {}),
                        style: Dg.ui(size: 15),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'İsim ara'),
                      ),
                    ),
                    if (q.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => query.clear()),
                        child: const Icon(Icons.close_rounded, size: 18, color: Dg.ink3),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: SegmentedTabs(
                labels: ['Bekleyen (${bekleyen.length})', 'Teslim (${teslim.length})', 'İade (${iade.length})'],
                index: tab,
                onChanged: (i) => setState(() => tab = i),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(q.isNotEmpty ? Icons.search_off_rounded : _emptyIcon(tab), size: 42, color: Dg.ink3),
                          const SizedBox(height: 14),
                          Text(q.isNotEmpty ? '"$q" için sonuç yok' : _emptyMessage(tab), style: Dg.ui(size: 15, color: Dg.ink3)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: rows.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final t = rows[i];
                        return StaggerIn(
                          index: i,
                          child: TaskListTile(
                            task: t,
                            canSeePricing: s.courier.canSeePricing,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: t.id)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
