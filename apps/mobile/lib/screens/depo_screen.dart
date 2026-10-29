import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'envanter_screen.dart';

class DepoScreen extends ConsumerWidget {
  const DepoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.depotTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(l.pickDepot, style: Dg.ui(size: 15, color: Dg.ink2)),
          const SizedBox(height: 16),
          for (var i = 0; i < s.depots.length; i++) ...[
            _DepotRow(
              depot: s.depots[i],
              selected: s.selectedDepot == i,
              onTap: () => s.pickDepot(i),
            ),
            const SizedBox(height: 10),
          ],
          if (s.selectedDepot != null) ...[
            const SizedBox(height: 8),
            Text(
              l.depotShipments,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 10),
            for (final p in s.depotPreview)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DgCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Mono(p.code, size: 12),
                          ],
                        ),
                      ),
                      Text(p.weight, style: Dg.ui(size: 13, color: Dg.ink2)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            DgButton(
              label: l.iPickedUp,
              icon: LucideIcons.packageCheck,
              onPressed: () {
                s.confirmDepotPickup();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const EnvanterScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DepotRow extends StatelessWidget {
  const _DepotRow({
    required this.depot,
    required this.selected,
    required this.onTap,
  });

  final DepotOption depot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: selected
          ? BoxDecoration(
              gradient: Dg.brandCta,
              borderRadius: BorderRadius.circular(Dg.radius),
              boxShadow: Dg.cardShadow,
            )
          : Dg.card(radius: Dg.radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dg.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                DgIconChip(
                  icon: LucideIcons.warehouse,
                  color: selected ? Dg.action : Colors.white,
                  background: selected ? Colors.white : Dg.plum,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        depot.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: selected ? Dg.onAction : Dg.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        depot.meta,
                        style: TextStyle(
                          fontSize: 14,
                          color: selected ? Dg.onAction : Dg.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? Dg.ink : Dg.elev,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${depot.count}',
                    style: TextStyle(
                      fontFamily: Dg.mono,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? Dg.purpleBright : Dg.ink3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
