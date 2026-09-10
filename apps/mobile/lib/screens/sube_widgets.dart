import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ortak "bu modül henüz gerçek bir backend'e bağlı değil" uyarısı — Şube
/// app'in 5 modülünden 4'ü bugün itibarıyla sadece demo veri gösteriyor
/// (bkz. docs/08-sube-acente-entegrasyonu.md §4). Gösterilen liste gerçek
/// akış şemasının tasarımını yansıtır, veri değil.
class SubeComingSoonBanner extends StatelessWidget {
  const SubeComingSoonBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DgCard(
      child: Row(
        children: [
          DgIcon(LucideIcons.construction, size: 18, color: Dg.warn, weight: 600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.subeComingSoon,
              style: Dg.ui(size: 13, color: Dg.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
