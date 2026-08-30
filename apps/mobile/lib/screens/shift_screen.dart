import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class ShiftScreen extends ConsumerWidget {
  const ShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vardiya başlat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'Bu fotoğraf yalnız vardiya kanıtı. Yüz aranmaz.',
            style: TextStyle(color: Dg.ink2, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 18),
          Viewfinder(
            captured: s.shiftPhotoTaken,
            aspectRatio: 3 / 4,
            hint: 'Yüzünüz kadrajda olsun.',
            capturedLabel: 'Kanıt alındı',
            onCapture: s.takeShiftPhoto,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: s.shiftPhotoTaken ? s.openShift : null,
            child: const Text('Vardiyayı aç'),
          ),
        ],
      ),
    );
  }
}
