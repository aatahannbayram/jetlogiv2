import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';

class SubeStockScreen extends StatelessWidget {
  const SubeStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tiles = <(String, String)>[
      (l.kpiBranchStock, '1.250'),
      ('Kullanılabilir', '980'),
      ('Kurye üzerinde', '200'),
      ('Sevkiyat bekleyen', '50'),
      ('Merkeze sevkiyatta', '12'),
      ('Hasarlı', '4'),
      ('Sayım farkında', '3'),
      (l.kpiInField, '200'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.subeStockTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (var i = 0; i < tiles.length; i += 2) ...[
            Row(
              children: [
                StatTile(label: tiles[i].$1, value: tiles[i].$2),
                const SizedBox(width: 12),
                StatTile(label: tiles[i + 1].$1, value: tiles[i + 1].$2),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text('Hareketler', style: Dg.ui(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          DgCard(
            child: Text('KL-2025-001 · giriş · 38 adet', style: Dg.ui(size: 14, color: Dg.ink2)),
          ),
          const SizedBox(height: 16),
          DgButton(label: l.stockIn, icon: LucideIcons.packagePlus, onPressed: () {}),
          const SizedBox(height: 8),
          DgButton(
            label: l.stockToCourier,
            icon: LucideIcons.userPlus,
            tone: DgButtonTone.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          DgButton(
            label: l.stockFromCourier,
            icon: LucideIcons.undo2,
            tone: DgButtonTone.secondary,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
