import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';
import 'zimmet_screen.dart';

/// Bottom nav'ın "Tara" sekmesi — canvas'ta referansı yoktu, menu_screen.dart'ın
/// zaten sunduğu iki zimmet-tarama modunu (kurye/şube) tek dokunuşla
/// erişilebilir kılan bir seçim ekranı olarak tasarlandı.
class TaraScreen extends StatelessWidget {
  const TaraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Tara sekmesi kök olarak (alt navdan) geri düğmesi istemiyor, ama
    // menu_screen.dart'ın "Zimmetim" satırından push edildiğinde de
    // açılıyor — o yoldan geldiğinde geri dönecek yer var, canPop bunu
    // ayırt ediyor (bkz. profile_screen.dart'taki aynı patern).
    final l = context.l10n;
    final canPop = Navigator.canPop(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 108),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPop) ...[
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Dg.elev,
                      shape: BoxShape.circle,
                    ),
                    child: DgIcon(LucideIcons.arrowLeft, size: 17, color: Dg.ink),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Appear(child: Display(l.scan, size: 26)),
              const SizedBox(height: 4),
              Appear(
                delay: const Duration(milliseconds: 40),
                child: Text(
                  l.scanHint,
                  style: Dg.ui(size: 14, color: Dg.ink2),
                ),
              ),
              const SizedBox(height: 24),
              StaggerIn(
                index: 0,
                child: _ScanOption(
                  icon: LucideIcons.qrCode,
                  title: l.courierCustody,
                  subtitle: l.courierCustodyHint,
                  tint: Dg.warnSoft,
                  ink: Dg.warn,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ZimmetScreen(mode: 'kurye'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StaggerIn(
                index: 1,
                child: _ScanOption(
                  icon: LucideIcons.qrCode,
                  title: l.branchCustody,
                  subtitle: l.branchCustodyHint,
                  tint: Dg.ok.withValues(alpha: 0.12),
                  ink: Dg.ok,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ZimmetScreen(mode: 'sube'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DgCard(
      onTap: onTap,
      child: Row(
        children: [
          IconTintBadge(icon: icon, tint: tint, ink: ink, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Dg.ui(size: 16, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: Dg.ui(size: 13, color: Dg.ink3)),
              ],
            ),
          ),
          DgIcon(LucideIcons.chevronRight, color: Dg.ink3),
        ],
      ),
    );
  }
}
