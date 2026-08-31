import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
                    child: Icon(LucideIcons.arrowLeft, size: 17, color: Dg.ink),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Display('Tara', size: 26),
              const SizedBox(height: 4),
              Text(
                'Zimmet almak veya teslim etmek için barkod okut.',
                style: Dg.ui(size: 14, color: Dg.ink2),
              ),
              const SizedBox(height: 24),
              _ScanOption(
                icon: LucideIcons.qrCode,
                title: 'Kurye Zimmet',
                subtitle: 'Şubeden üzerine alacağın paketleri okut',
                tint: Dg.redBg,
                ink: Dg.red,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ZimmetScreen(mode: 'kurye'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ScanOption(
                icon: LucideIcons.qrCode,
                title: 'Şube Zimmet',
                subtitle: 'Şubeye teslim ettiğin paketleri okut',
                tint: Dg.greenBg,
                ink: Dg.green,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ZimmetScreen(mode: 'sube'),
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
          Icon(LucideIcons.chevronRight, color: Dg.ink3),
        ],
      ),
    );
  }
}
