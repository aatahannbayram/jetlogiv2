import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../scan.dart';
import '../theme.dart';
import '../widgets.dart';

class SubeCountScreen extends StatefulWidget {
  const SubeCountScreen({super.key});

  @override
  State<SubeCountScreen> createState() => _SubeCountScreenState();
}

class _SubeCountScreenState extends State<SubeCountScreen> {
  bool _running = false;
  bool _paused = false;
  final _codes = <String>[];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeCountTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          DgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mono('SAY-2026-001', size: 12, color: Dg.ink3),
                Text('Genel stok sayımı', style: Dg.ui(size: 16, weight: FontWeight.w700)),
                Text('${_codes.length} okundu', style: Dg.ui(size: 13, color: Dg.ink2)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_running) ...[
            if (!_paused)
              BarcodeScanPane(
                known: _codes.toSet(),
                onDetect: (c) => setState(() {
                  if (!_codes.contains(c)) _codes.add(c);
                }),
              ),
            const SizedBox(height: 12),
            DgButton(
              label: _paused ? l.startCount : l.pauseCount,
              icon: _paused ? LucideIcons.play : LucideIcons.pause,
              onPressed: () => setState(() => _paused = !_paused),
            ),
            const SizedBox(height: 8),
            Text('${l.countDiff}: 3 eksik · 1 fazla', style: Dg.ui(size: 14, color: Dg.ink2)),
          ] else
            DgButton(
              label: l.startCount,
              icon: LucideIcons.play,
              onPressed: () => setState(() => _running = true),
            ),
        ],
      ),
    );
  }
}
