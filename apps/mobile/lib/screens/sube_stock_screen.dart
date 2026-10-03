import 'package:flutter/material.dart';

import '../api/jetdiji_branch_models.dart';
import '../theme.dart';

/// Şube stok adedi mobil API'de yok. Yerel yer tutucu.
class SubeStockScreen extends StatelessWidget {
  const SubeStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(JetDijiBranchKpis.stockLabel, style: Dg.stat(size: 48)),
            const SizedBox(height: 8),
            Text(
              'Şube stok adedi bu API’de yok.',
              style: TextStyle(color: Dg.ink2, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
