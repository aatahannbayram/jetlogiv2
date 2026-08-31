import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  final granted = <String>{};

  static const items = [
    ('Konum', 'Adrese vardığınızı doğrulamak için.', 'loc'),
    ('Kamera', 'Teslim ve vardiya kanıtı. Galeri kapalı.', 'cam'),
    ('Bildirim', 'Yeni görev ve zorunlu güncelleme.', 'push'),
  ];

  @override
  Widget build(BuildContext context) {
    final ready = granted.length == items.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Cihaz izinleri')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Vardiya ancak bunlar tamamsa açılır.',
            style: TextStyle(fontSize: 16, color: Dg.ink2, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                onTap: () => setState(() => granted.add(item.$3)),
                child: Row(
                  children: [
                    Icon(
                      granted.contains(item.$3)
                          ? LucideIcons.circleCheck
                          : LucideIcons.circle,
                      color: granted.contains(item.$3) ? Dg.accent : Dg.ink3,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: TextStyle(color: Dg.ink2, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: ready
                ? () => ref.read(sessionProvider).completePermissions()
                : null,
            child: Text(ready ? 'Vardiyaya geç' : 'Üç izni de ver'),
          ),
        ],
      ),
    );
  }
}
