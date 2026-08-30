import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result_screen.dart';

/// Dedicated "teslim edilemedi" reason picker, reached from [TaskDetailScreen]
/// and from the delivery wizard's "Teslim edemedim" button.
class FailScreen extends ConsumerStatefulWidget {
  const FailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<FailScreen> createState() => _FailScreenState();
}

class _FailScreenState extends ConsumerState<FailScreen> {
  static const reasons = [
    'Adres bulunamadı',
    'Alıcı adreste yok',
    'Alıcı teslim almadı',
    'Ödeme alınamadı',
    'Adres hatalı',
    'Siteye giriş izni yok',
  ];

  String? picked;
  final note = TextEditingController();
  bool closed = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final task = s.taskById(widget.taskId);

    if (closed) {
      return DeliveryResultScreen(
        success: false,
        task: task,
        online: s.online,
        next: null,
        onClose: () => Navigator.of(context).pop(true),
        onNext: () {},
      );
    }

    return Scaffold(
      appBar: AppBar(title: Mono(task.ref, size: 13, weight: FontWeight.w700, color: Dg.ink2)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Display('Neden teslim edilemedi?', size: 28),
          const SizedBox(height: 8),
          const Text(
            'Seçtiğin neden merkeze anında iletilir, gönderi iadeye düşer.',
            style: TextStyle(color: Dg.ink2, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          for (final r in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: picked == r ? Dg.redBg : Dg.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Dg.radius),
                  side: BorderSide(color: picked == r ? Dg.red : Dg.rule, width: picked == r ? 2 : 1),
                ),
                child: InkWell(
                  onTap: () => setState(() => picked = r),
                  borderRadius: BorderRadius.circular(Dg.radius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: picked == r ? Dg.red : Dg.ink),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: picked == r ? Dg.red : Dg.rule, width: 2),
                            color: picked == r ? Dg.red : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          DgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mono('EK NOT', size: 11, color: Dg.ink3),
                const SizedBox(height: 6),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'İsteğe bağlı açıklama',
                  ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (picked != null)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Dg.red),
              onPressed: () {
                ref.read(sessionProvider).returnTask(widget.taskId, reason: picked!, note: note.text.trim());
                setState(() => closed = true);
              },
              child: const Text('İade olarak kapat'),
            ),
        ],
      ),
    );
  }
}
