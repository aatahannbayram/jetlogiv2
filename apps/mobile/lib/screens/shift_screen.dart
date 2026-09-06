import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.startShiftTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          DgCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Dg.violetBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.camera, size: 20, color: Dg.violet),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.shiftSelfieHint,
                    style: TextStyle(color: Dg.ink2, fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Viewfinder(
            captured: s.shiftPhotoTaken,
            aspectRatio: 3 / 4,
            hint: l.faceInFrame,
            capturedLabel: l.proofTaken,
            frontCamera: true,
            onCapture: (path) => s.takeShiftPhoto(path),
          ),
          const SizedBox(height: 18),
          DgButton(
            label: l.openShift,
            icon: LucideIcons.sun,
            tone: DgButtonTone.brand,
            onPressed: (s.shiftPhotoTaken || s.bypassShiftGate)
                ? s.openShift
                : null,
          ),
        ],
      ),
    );
  }
}
