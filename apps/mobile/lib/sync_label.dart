import 'l10n.dart';
import 'models.dart';

/// Courier-facing view of one [OutboxEvent] — never wire names (`TASK_TRANSITION`)
/// or raw subject ids (`t1`). The outbox stays the real FIFO; this only names it.
enum SyncEventKind {
  accept,
  enRoute,
  arrived,
  start,
  fail,
  deliver,
  step,
  shiftOn,
  shiftOff,
  custody,
  ticket,
  other,
}

class SyncQueueView {
  const SyncQueueView({
    required this.person,
    required this.action,
    required this.meta,
    required this.kind,
  });

  /// Recipient, shift, or ticket — the name a courier already knows.
  final String person;

  /// What this queued record is: "Yola çıktı", "Alıcı yoktu".
  final String action;

  /// Shipment ref + clock, or a short fallback.
  final String meta;

  final SyncEventKind kind;
}

DeliveryTask? taskForSubject(List<DeliveryTask> tasks, String? id) {
  if (id == null) return null;
  for (final t in tasks) {
    if (t.id == id) return t;
  }
  return null;
}

SyncQueueView describeOutboxEvent(
  OutboxEvent event,
  List<DeliveryTask> tasks,
  L10n l,
) {
  final task = taskForSubject(tasks, event.subjectId);
  final person = switch (event.operation) {
    SyncOperation.shiftStart || SyncOperation.shiftEnd => l.shiftRecord,
    SyncOperation.supportTicketCreate =>
      _str(event.payload, 'subject') ?? l.supportTicket,
    SyncOperation.custodyHandover => l.custody,
    _ => task?.recipient ?? l.queuedRecord,
  };
  final action = _action(event, l);
  final bits = <String>[
    if (task != null) task.ref,
    _clock(event.occurredAt),
  ];
  return SyncQueueView(
    person: person,
    action: action,
    meta: bits.join(' · '),
    kind: _kind(event),
  );
}

SyncEventKind _kind(OutboxEvent event) {
  switch (event.operation) {
    case SyncOperation.shiftStart:
      return SyncEventKind.shiftOn;
    case SyncOperation.shiftEnd:
      return SyncEventKind.shiftOff;
    case SyncOperation.custodyHandover:
      return SyncEventKind.custody;
    case SyncOperation.supportTicketCreate:
      return SyncEventKind.ticket;
    case SyncOperation.stepSubmit:
      return SyncEventKind.step;
    case SyncOperation.taskFinalize:
      return _isFailure(event) ? SyncEventKind.fail : SyncEventKind.deliver;
    case SyncOperation.panelAccept:
      return SyncEventKind.accept;
    case SyncOperation.panelStart:
      return SyncEventKind.start;
    case SyncOperation.panelLocation:
      return SyncEventKind.enRoute;
    case SyncOperation.panelFinalize:
      return _isFailure(event) ? SyncEventKind.fail : SyncEventKind.deliver;
    case SyncOperation.taskTransition:
      return switch (_to(event)) {
        'ACCEPTED' => SyncEventKind.accept,
        'EN_ROUTE' => SyncEventKind.enRoute,
        'ARRIVED' => SyncEventKind.arrived,
        'IN_PROGRESS' => SyncEventKind.start,
        'FAILED' => SyncEventKind.fail,
        _ => _isFailure(event) ? SyncEventKind.fail : SyncEventKind.other,
      };
  }
}

String _action(OutboxEvent event, L10n l) {
  switch (event.operation) {
    case SyncOperation.shiftStart:
      return l.syncShiftStart;
    case SyncOperation.shiftEnd:
      return l.syncShiftEnd;
    case SyncOperation.custodyHandover:
      return l.syncCustodyHandover;
    case SyncOperation.supportTicketCreate:
      return l.syncSupportTicket;
    case SyncOperation.stepSubmit:
      return l.syncStepOf(_str(event.payload, 'stepKey') ?? '');
    case SyncOperation.taskFinalize:
      return l.syncOutcomeOf(
        _str(event.payload, 'outcomeCode') ??
            _str(event.payload, 'reason') ??
            '',
      );
    case SyncOperation.panelAccept:
      return l.syncTransitionOf('ACCEPTED');
    case SyncOperation.panelStart:
      return l.syncTransitionOf('IN_PROGRESS');
    case SyncOperation.panelLocation:
      return l.syncTransitionOf('EN_ROUTE');
    case SyncOperation.panelFinalize:
      return l.syncOutcomeOf(
        _str(event.payload, 'outcome') ??
            _str(event.payload, 'reasonCode') ??
            '',
      );
    case SyncOperation.taskTransition:
      final reason =
          _str(event.payload, 'reason') ??
          _str(event.payload, 'note') ??
          _str(event.payload, 'outcome');
      final to = _to(event);
      if (reason != null && (to == null || to == 'FAILED')) {
        return l.syncOutcomeOf(reason);
      }
      if (to != null && to.isNotEmpty) return l.syncTransitionOf(to);
      return l.syncOutcomeOf(reason ?? '');
  }
}

String? _to(OutboxEvent event) => _str(event.payload, 'to');

bool _isFailure(OutboxEvent event) {
  final to = _to(event);
  if (to == 'FAILED') return true;
  final code =
      _str(event.payload, 'outcomeCode') ??
      _str(event.payload, 'outcome') ??
      _str(event.payload, 'reasonCode') ??
      _str(event.payload, 'reason') ??
      '';
  return const {
    'FAILED',
    'ALICI_YOK',
    'TESLIM_EDILEMEDI',
    'RECIPIENT_ABSENT',
    'ADDRESS_NOT_FOUND',
    'REFUSED',
  }.contains(code);
}

String? _str(Map<String, Object?> payload, String key) {
  final v = payload[key];
  return v is String && v.isNotEmpty ? v : null;
}

String _clock(DateTime at) {
  final local = at.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
