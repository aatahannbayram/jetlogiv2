import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/notif.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kategori doğru türe ve ekrana gider', () {
    expect(serverNotifKind('SHIFT_AUTO_CLOSED', 'COURIER_WORK_SESSION'),
        NotifKind.shift);
    expect(notifOpenTarget(serverNotifKind('SHIFT_AUTO_CLOSED', null)),
        NotifOpenTarget.none);
    expect(serverNotifKind('EVIDENCE_REJECTED', null), NotifKind.photoRejected);
    expect(serverNotifKind('HANDOVER_CREATED', null), NotifKind.custody);
    expect(serverNotifKind('TASK_ASSIGNED', 'SHIPMENT'), NotifKind.stopAssigned);
    expect(serverNotifKind('ANNOUNCEMENT', null), NotifKind.shift);
  });

  test('metindeki ham ISO zaman okunur olur', () {
    final out = readableIsoInText(
      'son işlem zamanınızla (2026-11-17T10:40:32.396Z) kapatıldı',
    );
    expect(out.contains('2026-11-17T'), isFalse);
    expect(out, contains('17.11.2026'));
    expect(readableIsoInText('saat yok'), 'saat yok');
  });
}
