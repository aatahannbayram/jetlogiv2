import 'package:flutter/material.dart';

import '../l10n.dart';
import '../scan.dart';
import '../theme.dart';

Future<String?> showSubeScanSheet(BuildContext context, {required String hint}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Dg.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.scanAction, style: Dg.ui(size: 17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(hint, style: Dg.ui(size: 13, color: Dg.ink2)),
          const SizedBox(height: 12),
          BarcodeScanPane(
            onDetect: (code) => Navigator.of(ctx).pop(code),
          ),
        ],
      ),
    ),
  );
}
