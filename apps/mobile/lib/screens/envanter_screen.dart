import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class EnvanterScreen extends ConsumerStatefulWidget {
  const EnvanterScreen({super.key});

  @override
  ConsumerState<EnvanterScreen> createState() => _EnvanterScreenState();
}

class _EnvanterScreenState extends ConsumerState<EnvanterScreen> {
  final code = TextEditingController();

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    // Girişli kuryede liste gerçek görevlerden gelir: açık olanlar üzerinde,
    // teslim edilenler bitti. Örnek liste yalnız demo kullanımda görünür.
    final live = s.panelLoggedIn;
    final items = live
        ? [
            for (final t in s.tasks)
              if (t.isOpen || t.status == TaskStatus.delivered)
                InventoryItem(
                  code: t.ref,
                  name: t.recipient,
                  state: t.isOpen ? l.inventoryOnMe : l.statusDelivered,
                  done: !t.isOpen,
                ),
          ]
        : s.inventory;
    final pending = items.where((p) => !p.done).length;
    return Scaffold(
      appBar: AppBar(title: Text(l.inventoryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              StatTile(label: l.pendingCaps, value: '$pending'),
              const SizedBox(width: 12),
              StatTile(
                label: l.deliveredCaps,
                value: '${items.length - pending}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (live && items.isEmpty)
            DgEmptyState(
              icon: LucideIcons.package,
              title: l.inventoryEmptyTitle,
              body: l.inventoryEmptyBody,
            ),
          if (!live)
            DgCard(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: code,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        hintText: l.addByCode,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      onSubmitted: (v) {
                        s.addInventoryByCode(v);
                        code.clear();
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      s.addInventoryByCode(code.text);
                      code.clear();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Dg.ink,
                        shape: BoxShape.circle,
                      ),
                      child: DgIcon(
                        LucideIcons.plus,
                        size: 20,
                        color: Dg.ground,
                        weight: 600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DgCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    IconTintBadge(
                      icon: item.done
                          ? LucideIcons.circleCheck
                          : LucideIcons.package,
                      tint: item.done ? Dg.greenBg : Dg.elev,
                      ink: item.done ? Dg.green : Dg.ink,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Mono(item.code, size: 12),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: item.state,
                      tone: item.done ? 'lo' : 'mid',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
