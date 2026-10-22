import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'l10n.dart';
import 'theme.dart';
import 'web_print.dart';
import 'widgets.dart';

/// Web: hazırlanan etiket PDF'i için "Yazdır" adımı. PDF üretimi ve ağ
/// isteği bittikten sonra ayrı bir dokunuş gerekir; iOS paylaşım menüsünü
/// ancak doğrudan dokunuşla açar. Kullanıcı yazdırmaya geçtiyse true.
Future<bool> showLabelPdfSheet(
  BuildContext context,
  Uint8List pdf,
  int count,
) async {
  final l = context.l10n;
  final shared = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.webLabelsReady(count),
              style: Dg.ui(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(l.webPrintHint, style: Dg.ui(size: 13, color: Dg.ink3)),
            const SizedBox(height: 16),
            DgButton(
              label: l.webPrintNow,
              icon: LucideIcons.printer,
              onPressed: () {
                presentPdf(pdf, 'jetlogi-etiket.pdf');
                Navigator.of(sheet).pop(true);
              },
            ),
          ],
        ),
      ),
    ),
  );
  return shared ?? false;
}
