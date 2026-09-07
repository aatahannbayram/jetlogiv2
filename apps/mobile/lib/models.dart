import 'package:flutter/material.dart';

enum TaskKind { delivery, pickup, document }

enum TaskStatus { assigned, inProgress, delivered, failed, queued, cancelled }

/// Whether a courier works independently or is dispatched by an agency
/// ("acenta") — agency couriers never see per-delivery pricing.
enum CourierAffiliation { independent, agency }

/// How a courier is paid. Only independent couriers on [pieceRate] see
/// per-delivery prices; [fixedMonthly] couriers see a monthly figure instead.
enum CompensationType { pieceRate, fixedMonthly }

class Courier {
  const Courier({
    required this.fullName,
    required this.code,
    required this.phone,
    required this.city,
    required this.district,
    required this.vehicle,
    required this.employment,
    required this.availability,
    required this.hours,
    this.affiliation = CourierAffiliation.independent,
    this.compensationType = CompensationType.pieceRate,
    this.monthlyPayLabel = '₺18.500',
    this.photoUrl,
  });

  final String fullName;
  final String code;
  final String phone;
  final String city;
  final String district;
  final String vehicle;
  final String employment;
  final String availability;
  final String hours;
  final CourierAffiliation affiliation;
  final CompensationType compensationType;

  /// Shown instead of per-delivery pricing when [canSeePricing] is false.
  final String monthlyPayLabel;

  /// Asset or http portrait. Falls back to initials when null.
  final String? photoUrl;

  /// Acenta (agency) couriers never see pricing. Independent couriers only
  /// see it when they're paid per delivery (hakediş/parça başı) — fixed
  /// monthly couriers see [monthlyPayLabel] instead everywhere money would
  /// otherwise show.
  bool get canSeePricing =>
      affiliation == CourierAffiliation.independent &&
      compensationType == CompensationType.pieceRate;

  Courier copyWith({
    String? fullName,
    String? code,
    String? phone,
    String? city,
    String? district,
    String? vehicle,
    String? employment,
    String? availability,
    String? hours,
    CourierAffiliation? affiliation,
    CompensationType? compensationType,
    String? monthlyPayLabel,
    String? photoUrl,
  }) {
    return Courier(
      fullName: fullName ?? this.fullName,
      code: code ?? this.code,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      district: district ?? this.district,
      vehicle: vehicle ?? this.vehicle,
      employment: employment ?? this.employment,
      availability: availability ?? this.availability,
      hours: hours ?? this.hours,
      affiliation: affiliation ?? this.affiliation,
      compensationType: compensationType ?? this.compensationType,
      monthlyPayLabel: monthlyPayLabel ?? this.monthlyPayLabel,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

class DeliveryTask {
  DeliveryTask({
    required this.id,
    required this.ref,
    required this.recipient,
    required this.address,
    required this.window,
    required this.kind,
    required this.status,
    this.note,
    this.cod,
    this.otpRequired = false,
    this.sequence = 0,
    this.etaMinutes,
    this.receivedBy,
    this.lat = 38.1512,
    this.lng = 29.0614,
    this.custodyCount,
    this.custodyRef,
    this.slaMinutesLeft,
    this.signed = false,
    this.groupKey,
    this.rowVersion = 0,
    this.workflowVersion = 1,
    this.photoUrl,
    this.phone,
    String? wireStatus,
  }) : wireStatus = wireStatus ??
            switch (status) {
              TaskStatus.delivered => 'COMPLETED',
              TaskStatus.failed => 'FAILED',
              TaskStatus.cancelled => 'CANCELLED',
              TaskStatus.inProgress => 'IN_PROGRESS',
              TaskStatus.assigned || TaskStatus.queued => 'ASSIGNED',
            };

  final String id;
  final String ref;
  final String recipient;
  final String? photoUrl;
  final String? phone;
  final String address;
  final String window;
  final TaskKind kind;
  TaskStatus status;
  final String? note;
  final int? cod;
  final bool otpRequired;
  final int sequence;
  final int? etaMinutes;
  String? receivedBy;
  final double lat;
  final double lng;

  /// Bu durakla ilişkili zimmet kalem sayısı (ör. "Zimmet 2 kalem").
  final int? custodyCount;

  /// Zimmet referans kodu — görev detayında "Zimmet" kartının alt satırı
  /// (ör. "PRD-11207").
  final String? custodyRef;

  /// Teslim penceresinin kalan dakikası — "Teslim penceresi · 01:12 kaldı".
  final int? slaMinutesLeft;

  /// İmza zaten alınmış mı — dağıtım listesinde tamamlanan durağın "İmza"
  /// pili için.
  bool signed;

  /// Aynı değere sahip görevler "aynı adres" olarak gruplanıp "Birlikte
  /// teslim edilebilir" kartı altında gösterilir.
  final String? groupKey;

  /// Optimistic concurrency — Fastify `TaskSummary.rowVersion`.
  int rowVersion;

  /// Finalize body — listede yoksa 1; detay gelince güncellenir.
  int workflowVersion;

  /// Fastify `TaskStatus` teli. Dart [status] ACCEPTED/EN_ROUTE'u sıkıştırır.
  String wireStatus;

  bool get isOpen =>
      status == TaskStatus.assigned ||
      status == TaskStatus.inProgress ||
      status == TaskStatus.queued;

  bool get isClosed =>
      status == TaskStatus.delivered ||
      status == TaskStatus.failed ||
      status == TaskStatus.cancelled;

  String get slaLabel {
    final m = slaMinutesLeft;
    if (m == null) return '';
    final h = m ~/ 60;
    final mm = m % 60;
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  String? get personPhoto => photoUrl ?? personPhotoAsset(recipient);

  String get kindLabel => switch (kind) {
    TaskKind.delivery => 'Teslimat',
    TaskKind.pickup => 'Alım',
    TaskKind.document => 'Evrak',
  };
}

/// Kapı anahtarı: açık [groupKey] yoksa ~11 m'lik koordinat hücresi.
String doorKeyOf(DeliveryTask t) {
  final g = t.groupKey;
  if (g != null && g.isNotEmpty) return 'k:$g';
  return 'g:${t.lat.toStringAsFixed(4)},${t.lng.toStringAsFixed(4)}';
}

/// Aynı kapıdaki görevleri ilk görüldükleri yerde birleştirir.
/// Sıra korunur — rota zaman çizelgesi ve dağıtım listesi aynı grupları görür.
List<List<DeliveryTask>> groupTasksByDoor(Iterable<DeliveryTask> rows) {
  final list = rows.toList();
  final byKey = <String, List<DeliveryTask>>{};
  for (final t in list) {
    (byKey[doorKeyOf(t)] ??= []).add(t);
  }
  final out = <List<DeliveryTask>>[];
  final seen = <String>{};
  for (final t in list) {
    final key = doorKeyOf(t);
    if (byKey[key]!.length > 1) {
      if (seen.add(key)) out.add(byKey[key]!);
    } else {
      out.add([t]);
    }
  }
  return out;
}

class WizardStep {
  const WizardStep({
    required this.keyName,
    required this.type,
    required this.title,
    required this.hint,
  });

  final String keyName;
  final String type;
  final String title;
  final String hint;
}

enum SyncOperation {
  shiftStart,
  shiftEnd,
  taskTransition,
  stepSubmit,
  taskFinalize,
  custodyHandover,
  supportTicketCreate,
  panelAccept,
  panelStart,
  panelLocation,
  panelFinalize,
}

extension SyncOperationWire on SyncOperation {
  String get wire => switch (this) {
    SyncOperation.shiftStart => 'SHIFT_START',
    SyncOperation.shiftEnd => 'SHIFT_END',
    SyncOperation.taskTransition => 'TASK_TRANSITION',
    SyncOperation.stepSubmit => 'STEP_SUBMIT',
    SyncOperation.taskFinalize => 'TASK_FINALIZE',
    SyncOperation.custodyHandover => 'CUSTODY_HANDOVER',
    SyncOperation.supportTicketCreate => 'SUPPORT_TICKET_CREATE',
    SyncOperation.panelAccept => 'PANEL_ACCEPT',
    SyncOperation.panelStart => 'PANEL_START',
    SyncOperation.panelLocation => 'PANEL_LOCATION',
    SyncOperation.panelFinalize => 'PANEL_FINALIZE',
  };

  bool get isPanel => switch (this) {
    SyncOperation.panelAccept ||
    SyncOperation.panelStart ||
    SyncOperation.panelLocation ||
    SyncOperation.panelFinalize => true,
    _ => false,
  };

  /// Fastify `/v1/sync/batch` görev yazmaları. Panel oturumunda bunlar
  /// panele gitmeli, eski API'ye değil (demo tohum TASK_TRANSITION dahil).
  bool get isFastifyTaskWrite => switch (this) {
    SyncOperation.taskTransition ||
    SyncOperation.stepSubmit ||
    SyncOperation.taskFinalize ||
    SyncOperation.custodyHandover => true,
    _ => false,
  };

  static SyncOperation fromWire(String wire) => switch (wire) {
    'SHIFT_START' => SyncOperation.shiftStart,
    'SHIFT_END' => SyncOperation.shiftEnd,
    'TASK_TRANSITION' => SyncOperation.taskTransition,
    'STEP_SUBMIT' => SyncOperation.stepSubmit,
    'TASK_FINALIZE' => SyncOperation.taskFinalize,
    'CUSTODY_HANDOVER' => SyncOperation.custodyHandover,
    'SUPPORT_TICKET_CREATE' => SyncOperation.supportTicketCreate,
    'PANEL_ACCEPT' => SyncOperation.panelAccept,
    'PANEL_START' => SyncOperation.panelStart,
    'PANEL_LOCATION' => SyncOperation.panelLocation,
    'PANEL_FINALIZE' => SyncOperation.panelFinalize,
    _ => throw ArgumentError('Bilinmeyen sync operation: $wire'),
  };
}

class OutboxEvent {
  OutboxEvent({
    required this.clientEventId,
    required this.operation,
    required this.occurredAt,
    required this.sequence,
    this.subjectId,
    this.payload = const {},
    this.status = 'pending',
  });

  final String clientEventId;
  final SyncOperation operation;
  final String? subjectId;
  final DateTime occurredAt;
  final int sequence;
  final Map<String, Object?> payload;
  String status;

  bool get pending => status == 'pending';
}

enum NotifKind {
  stopAssigned,
  custody,
  syncFail,
  bonus,
  shift,
  stopPulled,
  stopCancelled,
  slaRisk,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.icon,
    required this.tint,
    required this.ink,
    this.taskId,
  });

  final String id;
  final NotifKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final IconData icon;
  final Color tint;
  final Color ink;
  final String? taskId;
}

class DepotOption {
  const DepotOption({
    required this.name,
    required this.meta,
    required this.count,
  });

  final String name;
  final String meta;
  final int count;
}

class DepotParcel {
  const DepotParcel({
    required this.code,
    required this.name,
    required this.weight,
  });

  final String code;
  final String name;
  final String weight;
}

class InventoryItem {
  const InventoryItem({
    required this.code,
    required this.name,
    required this.state,
    required this.done,
  });

  final String code;
  final String name;
  final String state;
  final bool done;

  InventoryItem copyWith({String? state, bool? done}) {
    return InventoryItem(
      code: code,
      name: name,
      state: state ?? this.state,
      done: done ?? this.done,
    );
  }
}

class KycDocOption {
  const KycDocOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class WeeklyBar {
  const WeeklyBar({required this.label, required this.value});

  final String label;
  final double value;
}

class BonusProgress {
  const BonusProgress({
    required this.label,
    required this.amount,
    required this.pct,
    required this.meta,
    required this.color,
  });

  final String label;
  final String amount;
  final double pct;
  final String meta;
  final Color color;
}

/// Haritadaki kurye konumu — kendi konum + filodaki diğerleri.
/// Canlı GPS / panel filoları aynı modele bağlanır.
class FleetCourier {
  const FleetCourier({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.self = false,
    this.status = 'on',
    this.photoUrl,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final bool self;
  final String status;
  final String? photoUrl;

  bool get onBreak => status == 'break';
}

/// Demo / known people — local portraits so the field UI works offline.
String? personPhotoAsset(String name) => switch (name.trim()) {
  'Ruken Turhan' => 'assets/images/avatars/ruken.jpg',
  'Ahmet Yılmaz' => 'assets/images/avatars/ahmet.jpg',
  'Elif Koç' => 'assets/images/avatars/elif.jpg',
  'Mehmet Aydın' => 'assets/images/avatars/mehmet.jpg',
  'Fatma Şahin' => 'assets/images/avatars/fatma.jpg',
  _ => null,
};
