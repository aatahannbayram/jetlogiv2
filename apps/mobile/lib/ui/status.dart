import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../motion.dart';
import '../theme.dart';

/// Durum tonu: renk + anlam. Hiçbir durum yalnız renkle anlatılmaz; hap her
/// zaman metin (ve çoğu zaman ikon) taşır (kılavuz s.35).
enum DgTone { info, ok, warn, bad, accent, neutral }

Color dgToneColor(DgTone tone) => switch (tone) {
  DgTone.info => Dg.brand,
  DgTone.ok => Dg.ok,
  DgTone.warn => Dg.warn,
  DgTone.bad => Dg.bad,
  DgTone.accent => Dg.violet,
  DgTone.neutral => Dg.text3,
};

/// Dolu ikon dairesinin rengi (beyaz ikon taşır).
Color dgToneBadge(DgTone tone) => switch (tone) {
  DgTone.info => Dg.badgeBlue,
  DgTone.ok => Dg.badgeGreen,
  DgTone.warn => Dg.badgeOrange,
  DgTone.bad => Dg.badgeRed,
  DgTone.accent => Dg.badgePurple,
  DgTone.neutral => Dg.badgeSlate,
};

/// Ekranda görünen durum: etiket + ton + ikon.
typedef DgStatus = ({String label, DgTone tone, IconData icon});

/// Tek durum sözlüğü: gönderi aşaması ve bayrakları → görünen durum.
/// Bütün listeler, detaylar ve haritalar buradan okur.
DgStatus shipmentStatus(L10n l, BranchShipmentRow row) => switch (row.stage) {
  BranchStage.incoming => (
    label: l.stageIncoming,
    tone: DgTone.neutral,
    icon: LucideIcons.arrowDownToLine,
  ),
  BranchStage.awaitingCourier => (
    label: l.stageAwaiting,
    tone: DgTone.warn,
    icon: LucideIcons.userPlus,
  ),
  BranchStage.inQueue => (
    label: l.stageInQueue,
    tone: DgTone.accent,
    icon: LucideIcons.hourglass,
  ),
  BranchStage.inDistribution => (
    label: l.filterOut,
    tone: DgTone.info,
    icon: LucideIcons.truck,
  ),
};

/// Kurye canlı durumu → görünen durum (Dağıtımda / Müsait / Molada /
/// Çevrimdışı). Dağıtımda = aktif ve üzerinde gönderi var.
DgStatus courierStatus(L10n l, {required String live, required int holding}) {
  if (live == 'ACTIVE' && holding > 0) {
    return (label: l.courierOut, tone: DgTone.info, icon: LucideIcons.bike);
  }
  if (live == 'ACTIVE') {
    return (
      label: l.courierFree,
      tone: DgTone.ok,
      icon: LucideIcons.circleCheck,
    );
  }
  if (live == 'BREAK') {
    return (label: l.liveBreak, tone: DgTone.warn, icon: LucideIcons.coffee);
  }
  return (
    label: l.liveOffline,
    tone: DgTone.neutral,
    icon: LucideIcons.wifiOff,
  );
}

/// Renkli durum hapı. Ton değişince renk yumuşakça geçer.
class DgStatusPill extends StatelessWidget {
  const DgStatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
  });

  DgStatusPill.of(DgStatus status, {super.key, this.dense = false})
    : label = status.label,
      tone = status.tone,
      icon = status.icon;

  final String label;
  final DgTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = dgToneColor(tone);
    return AnimatedContainer(
      duration: DgMotion.quick,
      curve: DgMotion.enter,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: Dg.dark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Dg.ui(
                size: 14,
                weight: FontWeight.w600,
                color: color,
                height: 1.1,
              ).copyWith(fontSize: dense ? 11 : 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dolu renkli daire ikon (mockup KPI rozeti).
class DgIconBadge extends StatelessWidget {
  const DgIconBadge({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 40,
    this.soft = false,
  });

  final IconData icon;
  final DgTone tone;
  final double size;

  /// Yumuşak: renkli zemin yerine renkli ikon + soluk zemin.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final solid = dgToneBadge(tone);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: soft
            ? dgToneColor(tone).withValues(alpha: Dg.dark ? 0.16 : 0.10)
            : solid,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: size * 0.46,
        color: soft ? dgToneColor(tone) : Colors.white,
      ),
    );
  }
}
