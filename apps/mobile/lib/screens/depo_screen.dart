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
          Text(
            l.pickDepot,
            style: Dg.ui(size: 15, color: Dg.ink2),
          ),
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
                                fontSize: 15,
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
      decoration: BoxDecoration(
        gradient: selected ? Dg.primaryGradient : null,
        color: selected ? null : Dg.surface,
        borderRadius: BorderRadius.circular(Dg.radius),
        border: selected ? null : Border.all(color: Dg.rule),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dg.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        depot.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: selected ? Colors.white : Dg.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        depot.meta,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? const Color(0xFFE3D9F2) : Dg.ink2,
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
                      fontSize: 12,
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
