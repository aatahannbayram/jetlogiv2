import 'package:flutter/material.dart';

enum TaskKind { delivery, pickup, document }

enum TaskStatus { assigned, inProgress, delivered, failed, queued }

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

  /// Acenta (agency) couriers never see pricing. Independent couriers only
  /// see it when they're paid per delivery (hakediş/parça başı) — fixed
  /// monthly couriers see [monthlyPayLabel] instead everywhere money would
  /// otherwise show.
  bool get canSeePricing =>
      affiliation == CourierAffiliation.independent && compensationType == CompensationType.pieceRate;

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
  });

  final String id;
  final String ref;
  final String recipient;
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

  String get kindLabel => switch (kind) {
        TaskKind.delivery => 'Teslimat',
        TaskKind.pickup => 'Alım',
        TaskKind.document => 'Evrak',
      };
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

class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.tint,
    required this.ink,
  });

  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color tint;
  final Color ink;
}

class DepotOption {
  const DepotOption({required this.name, required this.meta, required this.count});

  final String name;
  final String meta;
  final int count;
}

class DepotParcel {
  const DepotParcel({required this.code, required this.name, required this.weight});

  final String code;
  final String name;
  final String weight;
}

class InventoryItem {
  const InventoryItem({required this.code, required this.name, required this.state, required this.done});

  final String code;
  final String name;
  final String state;
  final bool done;

  InventoryItem copyWith({String? state, bool? done}) {
    return InventoryItem(code: code, name: name, state: state ?? this.state, done: done ?? this.done);
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
