import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'models.dart';
import 'theme.dart';

enum NotifFilter { all, unread, alerts }

enum NotifDayGroup { today, yesterday, earlier }

enum NotifOpenTarget { task, sync, custody, earnings, mistakes, none }

bool notifIsAlert(NotifKind kind) =>
    kind == NotifKind.syncFail ||
    kind == NotifKind.stopCancelled ||
    kind == NotifKind.stopPulled ||
    kind == NotifKind.slaRisk ||
    kind == NotifKind.photoRejected;

NotifOpenTarget notifOpenTarget(NotifKind kind) => switch (kind) {
  NotifKind.stopAssigned ||
  NotifKind.stopCancelled ||
  NotifKind.stopPulled ||
  NotifKind.slaRisk => NotifOpenTarget.task,
  NotifKind.syncFail => NotifOpenTarget.sync,
  NotifKind.custody => NotifOpenTarget.custody,
  NotifKind.bonus => NotifOpenTarget.earnings,
  NotifKind.photoRejected => NotifOpenTarget.mistakes,
  NotifKind.shift => NotifOpenTarget.none,
};

NotifKind notifKindFromPush(String kind) => switch (kind) {
  'TASK_ASSIGNED' || 'TASK_UPDATED' => NotifKind.stopAssigned,
  'TASK_CANCELLED' => NotifKind.stopCancelled,
  'TASK_PULLED' => NotifKind.stopPulled,
  'SHIFT_REMINDER' => NotifKind.shift,
  'CUSTODY_TAKEN' => NotifKind.custody,
  'SLA_AT_RISK' => NotifKind.slaRisk,
  'EVIDENCE_REJECTED' => NotifKind.photoRejected,
  'SUPPORT_REPLY' || 'ANNOUNCEMENT' || 'ROUTE_RECALCULATED' => NotifKind.shift,
  _ => NotifKind.stopAssigned,
};

({IconData icon, Color tint, Color ink}) notifLook(NotifKind kind) =>
    switch (kind) {
      NotifKind.stopAssigned => (
        icon: LucideIcons.truck,
        tint: Dg.greenBg,
        ink: Dg.green,
      ),
      NotifKind.photoRejected => (
        icon: LucideIcons.cameraOff,
        tint: Dg.redBg,
        ink: Dg.red,
      ),
      NotifKind.stopCancelled || NotifKind.syncFail => (
        icon: LucideIcons.circleAlert,
        tint: Dg.redBg,
        ink: Dg.red,
      ),
      NotifKind.stopPulled || NotifKind.slaRisk => (
        icon: LucideIcons.truck,
        tint: Dg.amberBg,
        ink: Dg.amber,
      ),
      NotifKind.custody => (
        icon: LucideIcons.package,
        tint: Dg.violetBg,
        ink: Dg.violet,
      ),
      NotifKind.bonus => (
        icon: LucideIcons.wallet,
        tint: Dg.amberBg,
        ink: Dg.amber,
      ),
      NotifKind.shift => (
        icon: LucideIcons.clock,
        tint: Dg.blueBg,
        ink: Dg.blue,
      ),
    };

AppNotification appNotificationFromInbox(Map<String, dynamic> raw) {
  final kind = notifKindFromPush(raw['kind'] as String? ?? '');
  final look = notifLook(kind);
  final created = DateTime.tryParse(raw['createdAt'] as String? ?? '') ??
      DateTime.now();
  return AppNotification(
    id: raw['id'] as String? ?? '',
    kind: kind,
    title: raw['title'] as String? ?? '',
    body: raw['body'] as String? ?? '',
    createdAt: created,
    icon: look.icon,
    tint: look.tint,
    ink: look.ink,
    taskId: raw['subjectId'] as String? ?? raw['taskId'] as String?,
  );
}

NotifDayGroup notifDayGroup(DateTime createdAt, DateTime now) {
  final local = createdAt.toLocal();
  final startToday = DateTime(now.year, now.month, now.day);
  final startLocal = DateTime(local.year, local.month, local.day);
  if (startLocal == startToday) return NotifDayGroup.today;
  if (startLocal == startToday.subtract(const Duration(days: 1))) {
    return NotifDayGroup.yesterday;
  }
  return NotifDayGroup.earlier;
}

String formatNotifTime(
  DateTime createdAt,
  DateTime now, {
  required String yesterdayLabel,
}) {
  final local = createdAt.toLocal();
  final startToday = DateTime(now.year, now.month, now.day);
  final startLocal = DateTime(local.year, local.month, local.day);
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (startLocal == startToday) return '$hh:$mm';
  if (startLocal == startToday.subtract(const Duration(days: 1))) {
    return yesterdayLabel;
  }
  return '${local.day}.${local.month.toString().padLeft(2, '0')}';
}

/// Ertesi 08:50 — vardiya öncesi hatırlatma (tam saat değil, Android inexact).
DateTime nextShiftReminderAt(DateTime now, {int hour = 8, int minute = 50}) {
  var at = DateTime(now.year, now.month, now.day, hour, minute);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  return at;
}

AppNotification? notificationById(List<AppNotification> items, String id) {
  for (final n in items) {
    if (n.id == id) return n;
  }
  return null;
}

List<AppNotification> filterNotifications({
  required List<AppNotification> items,
  required NotifFilter filter,
  required bool Function(String id) isRead,
}) {
  switch (filter) {
    case NotifFilter.all:
      return items;
    case NotifFilter.unread:
      return [for (final n in items) if (!isRead(n.id)) n];
    case NotifFilter.alerts:
      return [for (final n in items) if (notifIsAlert(n.kind)) n];
  }
}

/// Sunucu bildirim kategorisi → ekrandaki tür. Tür, dokununca açılacak
/// ekranı da belirler; bilinmeyen kategori hiçbir ekrana götürmez.
NotifKind serverNotifKind(String category, String? sourceType) {
  final c = category.toUpperCase();
  if (c == 'EVIDENCE_REJECTED' || c.startsWith('MISTAKE')) {
    return NotifKind.photoRejected;
  }
  if (c.startsWith('HANDOVER') || c.startsWith('CUSTODY')) {
    return NotifKind.custody;
  }
  if (c == 'TASK_CANCELLED') return NotifKind.stopCancelled;
  if (c == 'TASK_PULLED' || c == 'TASK_REASSIGNED') return NotifKind.stopPulled;
  if (c.startsWith('SLA')) return NotifKind.slaRisk;
  if (c.startsWith('TASK') || sourceType == 'SHIPMENT') {
    return NotifKind.stopAssigned;
  }
  if (c.startsWith('BONUS') || c.startsWith('EARNING')) return NotifKind.bonus;
  return NotifKind.shift;
}

/// Metindeki ham ISO zamanı ("2026-11-17T10:40:32.396Z") yerel
/// "17.11.2026 13:40" biçimine çevirir; başka metne dokunmaz.
String readableIsoInText(String text) {
  final iso = RegExp(
    r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?',
  );
  return text.replaceAllMapped(iso, (m) {
    final t = DateTime.tryParse(m[0]!);
    if (t == null) return m[0]!;
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  });
}
