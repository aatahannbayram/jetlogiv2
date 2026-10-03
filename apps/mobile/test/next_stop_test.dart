import 'package:dijigoo_kurye/models.dart';
import 'package:dijigoo_kurye/next_stop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adres ilçe/il tekrarını düşürür', () {
    final a = parseStopAddress(
      'Kayalık Mah. Cumhuriyet Cd. No:14, Güney / Denizli',
    );
    expect(a.street, 'Cumhuriyet Cd. No:14');
    expect(a.hood, 'Kayalık Mah.');
  });

  test('mahalle yoksa sokak tek satır kalır', () {
    final a = parseStopAddress('İstiklal Cd. No:8 D:3, Güney / Denizli');
    expect(a.street, 'İstiklal Cd. No:8 D:3');
    expect(a.hood, isNull);
  });

  test('randevu penceresi parse edilir', () {
    final w = parseAppointmentWindow(
      '14:30–15:00',
      slaMinutesLeft: 72,
    );
    expect(w, isNotNull);
    expect(w!.label, '14:30 – 15:00');
    expect(w.urgent, isFalse);
  });

  test('45 dk altı acil', () {
    final w = parseAppointmentWindow('15:00-15:30', slaMinutesLeft: 20);
    expect(w!.urgent, isTrue);
  });

  test('boş pencere satırı yok', () {
    expect(parseAppointmentWindow('—'), isNull);
    expect(parseAppointmentWindow(''), isNull);
  });

  test('konum yokken enroute', () {
    expect(
      nextStopPhase(
        selfLocated: false,
        arrivedManual: false,
        distanceMeters: 40,
        status: TaskStatus.assigned,
      ),
      NextStopPhase.enroute,
    );
  });

  test('150 m ve altı arrived', () {
    expect(
      nextStopPhase(
        selfLocated: true,
        arrivedManual: false,
        distanceMeters: 150,
        status: TaskStatus.assigned,
      ),
      NextStopPhase.arrived,
    );
  });

  test('uzak mesafe enroute', () {
    expect(
      nextStopPhase(
        selfLocated: true,
        arrivedManual: false,
        distanceMeters: 800,
        status: TaskStatus.assigned,
      ),
      NextStopPhase.enroute,
    );
  });

  test('manuel vardım arrived', () {
    expect(
      nextStopPhase(
        selfLocated: false,
        arrivedManual: true,
        distanceMeters: 800,
        status: TaskStatus.assigned,
      ),
      NextStopPhase.arrived,
    );
  });
}
