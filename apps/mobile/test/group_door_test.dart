import 'package:dijigoo_kurye/models.dart';
import 'package:flutter_test/flutter_test.dart';

DeliveryTask _task(
  String id,
  String name, {
  double lat = 38.1481,
  double lng = 29.0558,
  String? groupKey,
}) {
  return DeliveryTask(
    id: id,
    ref: id,
    recipient: name,
    address: 'İstiklal Cd.',
    window: '15:00',
    kind: TaskKind.delivery,
    status: TaskStatus.assigned,
    lat: lat,
    lng: lng,
    groupKey: groupKey,
  );
}

void main() {
  test('groupTasksByDoor: groupKey birleştirir, sırayı korur', () {
    final grouped = groupTasksByDoor([
      _task('t1', 'Ahmet', lat: 38.1512, lng: 29.0614),
      _task('t2', 'Elif', groupKey: 'istiklal-8'),
      _task('t5', 'Zeynep', groupKey: 'istiklal-8'),
      _task('t4', 'Fatma', lat: 38.1460, lng: 29.0488),
    ]);
    expect(grouped, hasLength(3));
    expect(grouped[0].single.recipient, 'Ahmet');
    expect(grouped[1].map((t) => t.id), ['t2', 't5']);
    expect(grouped[2].single.recipient, 'Fatma');
  });

  test('groupTasksByDoor: groupKey yoksa aynı koordinat tek kapıdır', () {
    final grouped = groupTasksByDoor([
      _task('a', 'Elif', lat: 38.1481, lng: 29.0558),
      _task('b', 'Zeynep', lat: 38.1481, lng: 29.0558),
      _task('c', 'Ahmet', lat: 38.1512, lng: 29.0614),
    ]);
    expect(grouped, hasLength(2));
    expect(grouped.first.map((t) => t.recipient), ['Elif', 'Zeynep']);
    expect(grouped.last.single.recipient, 'Ahmet');
  });
}
