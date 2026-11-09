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

/// Kuryenin listede ve haritada görünen durumu. Mola vardiya kaydından
/// gelir; `liveStatus` BREAK yalnız konumun 10–60 dk eski olduğunu söyler,
/// mola demek değildir.
enum CourierKind { out, free, onBreak, offline }

CourierKind courierKind(BranchCourierLive c, {bool onBreak = false}) {
  if (c.liveStatus == 'OFFLINE') return CourierKind.offline;
  if (onBreak) return CourierKind.onBreak;
  return c.holdingCount > 0 ? CourierKind.out : CourierKind.free;
}

/// Kurye durumu → görünen durum (Dağıtımda / Müsait / Molada /
/// Çevrimdışı).
DgStatus courierStatus(L10n l, CourierKind kind) => switch (kind) {
  CourierKind.out => (
    label: l.courierOut,
    tone: DgTone.info,
    icon: LucideIcons.bike,
  ),
  CourierKind.free => (
    label: l.courierFree,
    tone: DgTone.ok,
    icon: LucideIcons.circleCheck,
  ),
  CourierKind.onBreak => (
    label: l.courierOnBreak,
    tone: DgTone.warn,
    icon: LucideIcons.coffee,
  ),
  CourierKind.offline => (
    label: l.liveOffline,
    tone: DgTone.neutral,
    icon: LucideIcons.wifiOff,
  ),
};

/// Harita iğnesinin halka rengi için `FleetCourier.status` değeri.
String courierPinStatus(CourierKind kind) => switch (kind) {
  CourierKind.out => 'out',
  CourierKind.free => 'on',
  CourierKind.onBreak => 'break',
  CourierKind.offline => 'offline',
};

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
    if (soft) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dgToneColor(tone).withValues(alpha: Dg.dark ? 0.16 : 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.46, color: dgToneColor(tone)),
      );
    }
    // Teslim v1.1 dili: yöntem kutularındaki gibi renkli ikon, tonlu cam
    // zemin ve ince renkli kenar (dolu renk daire yerine).
    final c = _glassTone(tone);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withValues(alpha: Dg.dark ? 0.26 : 0.16),
            c.withValues(alpha: Dg.dark ? 0.08 : 0.06),
          ],
        ),
        border: Border.all(color: c.withValues(alpha: Dg.dark ? 0.45 : 0.30)),
      ),
      child: Icon(icon, size: size * 0.48, color: c),
    );
  }

  static Color _glassTone(DgTone tone) => Dg.dark
      ? switch (tone) {
          DgTone.info => Dg.dgTurkuaz,
          DgTone.ok => const Color(0xFF4ADE80),
          DgTone.warn => const Color(0xFFFBBF24),
          DgTone.bad => const Color(0xFFFF7A8A),
          DgTone.accent => const Color(0xFFB98BFF),
          DgTone.neutral => const Color(0xFFB9C0D9),
        }
      : dgToneBadge(tone);
}

/// Gönderi olayı / şube audit kodu → okunur başlık ve ton. Bilinmeyen kod
/// olduğu gibi (alt çizgisiz) gösterilir; uydurma etiket verilmez.
({String title, DgTone tone}) shipmentEventView(L10n l, ShipmentEvent e) {
  final c = e.code.toUpperCase();
  if (c.contains('HANDOVER_CANCEL')) {
    return (title: l.evHandoverCancelled, tone: DgTone.neutral);
  }
  if (c.contains('HANDOVER_CHANGE') || c.contains('REASSIGN')) {
    return (title: l.evCourierChanged, tone: DgTone.accent);
  }
  if (c.contains('HANDOVER_ACCEPT') || c.contains('CUSTODY_ACCEPT')) {
    return (title: l.evAccepted, tone: DgTone.info);
  }
  if (c.contains('HANDOVER')) return (title: l.evHandover, tone: DgTone.info);
  if (c.contains('RETURN')) return (title: l.evReturned, tone: DgTone.warn);
  if (c.contains('ARRIVED')) return (title: l.evArrived, tone: DgTone.info);
  if (c.contains('RECIPIENT_CALL')) {
    return (title: l.evCalled, tone: DgTone.neutral);
  }
  if (c.contains('NOT_DELIVERED') || c.contains('DELIVERY_FAILED')) {
    return (title: l.evFailed, tone: DgTone.bad);
  }
  if (c.contains('DELIVERED')) return (title: l.evDelivered, tone: DgTone.ok);
  if (c.contains('RECEIVED') || c.contains('INTAKE')) {
    return (title: l.evReceived, tone: DgTone.ok);
  }
  final raw = e.code.replaceAll('_', ' ').toLowerCase();
  return (
    title: raw.isEmpty ? '—' : raw[0].toUpperCase() + raw.substring(1),
    tone: DgTone.neutral,
  );
}
