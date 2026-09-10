import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(l.inventoryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: l.pendingCaps,
                  value: '${s.inventoryPending}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(label: l.deliveredCaps, value: '${s.inventoryDone}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DgCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: code,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Dg.brand,
                      shape: BoxShape.circle,
                    ),
                    child: DgIcon(
                      LucideIcons.plus,
                      size: 20,
                      color: Colors.white,
                      weight: 600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final item in s.inventory)
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
                      tint: item.done ? Dg.greenBg : Dg.amberBg,
                      ink: item.done ? Dg.green : Dg.amber,
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
                              fontSize: 15,
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
