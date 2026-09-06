import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'models.dart';
import 'theme.dart';

enum NotifFilter { all, unread, alerts }

enum NotifDayGroup { today, yesterday, earlier }

enum NotifOpenTarget { task, sync, custody, earnings, none }

bool notifIsAlert(NotifKind kind) =>
    kind == NotifKind.syncFail ||
    kind == NotifKind.stopCancelled ||
    kind == NotifKind.stopPulled ||
    kind == NotifKind.slaRisk;

NotifOpenTarget notifOpenTarget(NotifKind kind) => switch (kind) {
  NotifKind.stopAssigned ||
  NotifKind.stopCancelled ||
  NotifKind.stopPulled ||
  NotifKind.slaRisk => NotifOpenTarget.task,
  NotifKind.syncFail => NotifOpenTarget.sync,
  NotifKind.custody => NotifOpenTarget.custody,
  NotifKind.bonus => NotifOpenTarget.earnings,
  NotifKind.shift => NotifOpenTarget.none,
};

NotifKind notifKindFromPush(String kind) => switch (kind) {
  'TASK_ASSIGNED' || 'TASK_UPDATED' => NotifKind.stopAssigned,
  'TASK_CANCELLED' => NotifKind.stopCancelled,
  'TASK_PULLED' => NotifKind.stopPulled,
  'SHIFT_REMINDER' => NotifKind.shift,
  'CUSTODY_TAKEN' => NotifKind.custody,
  'SLA_AT_RISK' => NotifKind.slaRisk,
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
