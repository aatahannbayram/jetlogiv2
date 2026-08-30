import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
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
              child: Row(
                children: [
                  const Expanded(child: Display('Dağıtım', size: 26)),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Dg.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Dg.rule)),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 16, color: Dg.ink3),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: query,
                            onChanged: (_) => setState(() {}),
                            style: Dg.ui(size: 14),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'İsim ara'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          const Icon(Icons.inbox_outlined, size: 42, color: Dg.ink3),
                          const SizedBox(height: 14),
                          Text('Bu sekmede kayıt yok', style: Dg.ui(size: 15, color: Dg.ink3)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: rows.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final t = rows[i];
                        return TaskListTile(
                          task: t,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(taskId: t.id)),
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
