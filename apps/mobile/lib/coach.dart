import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// İlk ziyaret kartı — eğitim modülü yerine kısa tooltip.
class CoachBanner extends StatelessWidget {
  const CoachBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DgIcon(LucideIcons.lightbulb, size: 18, color: Dg.warn, weight: 600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: Dg.ui(size: 15, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: Dg.ui(size: 14, color: Dg.ink2, height: 1.35)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDismiss,
              child: Text(l.tipGotIt),
            ),
          ),
        ],
      ),
    );
  }
}
