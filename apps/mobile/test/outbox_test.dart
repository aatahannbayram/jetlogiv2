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
}
