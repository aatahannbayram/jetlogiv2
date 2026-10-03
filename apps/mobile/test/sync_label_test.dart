import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/sync_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const l = L10n('tr');

  test('tohum kaydı Fatma Şahin ve alıcı yok diye adlandırılır', () {
    final s = SessionController();
    final view = describeOutboxEvent(s.outbox.events.single, s.tasks, l);
    expect(view.person, 'Fatma Şahin');
    expect(view.action, 'Alıcı adreste yok');
    expect(view.meta, contains('DGO-8844'));
    expect(view.kind, SyncEventKind.fail);
    expect(s.outbox.events.single.operation.wire, 'TASK_TRANSITION');
  });

  test('teslime başlama zinciri kurye adımlarını gösterir', () {
    final s = SessionController();
    s.online = false;
    s.startTask('t1');
    final views = [
      for (final e in s.outbox.events.where((e) => e.subjectId == 't1'))
        describeOutboxEvent(e, s.tasks, l),
    ];
    expect(views.map((v) => v.person).toSet(), {'Ahmet Yılmaz'});
    expect(views.map((v) => v.action), [
      'Görevi aldı',
      'Yola çıktı',
      'Kapıya vardı',
      'Teslime başladı',
    ]);
    expect(views.every((v) => v.meta.contains('DGO-8841')), isTrue);
  });

  test('teslim finalize alıcı adı ve teslim edildi der', () {
    final s = SessionController();
    s.online = false;
    s.deliverTask('t2', receivedBy: 'Alıcının kendisi');
    final last = s.outbox.events.last;
    final view = describeOutboxEvent(last, s.tasks, l);
    expect(view.person, 'Elif Koç');
    expect(view.action, 'Teslim edildi');
    expect(view.kind, SyncEventKind.deliver);
  });
}
