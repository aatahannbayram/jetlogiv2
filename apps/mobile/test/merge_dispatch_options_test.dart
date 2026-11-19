import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kurye ancak her gönderiye uygunsa uygun görünür', () {
    const a = DispatchOptions(couriers: [
      CourierOption(id: '1', name: 'K1'),
      CourierOption(id: '2', name: 'K2'),
    ]);
    const b = DispatchOptions(ready: false, couriers: [
      CourierOption(id: '1', name: 'K1', eligible: false),
      CourierOption(id: '2', name: 'K2'),
    ]);
    final m = mergeDispatchOptions([a, b]);
    expect(m.ready, isFalse);
    expect(m.couriers.firstWhere((c) => c.id == '1').eligible, isFalse);
    expect(m.couriers.firstWhere((c) => c.id == '2').eligible, isTrue);
  });
}
