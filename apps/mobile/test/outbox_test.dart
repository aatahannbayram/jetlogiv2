import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kuyrukta bir senkron olayıyla açılır', () {
    final s = SessionController();
    expect(s.pendingSync, 1);
    expect(s.outbox.events.single.operation, SyncOperation.taskTransition);
    expect(s.outbox.events.single.subjectId, 't4');
  });

  test('teslim TASK_FINALIZE yazar ve çevrimiçiyken applied olur', () {
    final s = SessionController();
    s.startTask('t1');
    s.deliverTask('t1', receivedBy: 'Alıcının kendisi');
    final last = s.outbox.events.last;
    expect(last.operation, SyncOperation.taskFinalize);
    expect(last.subjectId, 't1');
    expect(last.status, 'applied');
    expect(last.payload['outcomeCode'], 'DELIVERED');
    expect(last.payload['clientEventId'], last.clientEventId);
    expect(s.pendingSync, 1);
  });

  test('teslim edilemedi kuyruğa düşer', () {
    final s = SessionController();
    s.startTask('t1');
    s.failTask('t1');
    expect(s.online, isFalse);
    expect(s.outbox.events.last.operation, SyncOperation.taskTransition);
    expect(s.outbox.events.last.status, 'pending');
    expect(s.pendingSync, 2);
  });

  test('PANEL_* wire hydrate edilir, Fastify TASK_* ile karışmaz', () {
    expect(SyncOperationWire.fromWire('PANEL_ACCEPT'), SyncOperation.panelAccept);
    expect(SyncOperationWire.fromWire('PANEL_START'), SyncOperation.panelStart);
    expect(
      SyncOperationWire.fromWire('PANEL_LOCATION'),
      SyncOperation.panelLocation,
    );
      expect(
        SyncOperationWire.fromWire('PANEL_FINALIZE'),
        SyncOperation.panelFinalize,
      );
    expect(
      SyncOperationWire.fromWire('PANEL_TICKET_CREATE'),
      SyncOperation.panelTicketCreate,
    );
    expect(
      SyncOperationWire.fromWire('PANEL_CUSTODY_RETURN'),
      SyncOperation.panelCustodyReturn,
    );
    expect(SyncOperation.panelTicketCreate.isPanel, isTrue);
    expect(SyncOperation.panelCustodyReturn.isPanel, isTrue);
    expect(SyncOperation.supportTicketCreate.isPanel, isFalse);
    expect(SyncOperation.panelAccept.wire, 'PANEL_ACCEPT');
    expect(SyncOperation.panelAccept.isPanel, isTrue);
    expect(SyncOperation.taskTransition.isPanel, isFalse);
    expect(SyncOperation.taskTransition.isFastifyTaskWrite, isTrue);
    expect(SyncOperation.panelStart.isFastifyTaskWrite, isFalse);
  });
}
