import 'package:dijigoo_kurye/log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('halka tampon katman sayılarını tutar ve eskiyi atar', () {
    for (var i = 0; i < 12; i++) {
      DgLog.i(LogLayer.session, 's$i');
      DgLog.d(LogLayer.route, 'r$i');
    }
    final last = DgLog.snapshot(last: 8);
    expect(last.length, 8);
    expect(last.last.layer, LogLayer.route);
    expect(DgLog.counts[LogLayer.session]! >= 12, isTrue);
    expect(DgLog.counts[LogLayer.route]! >= 12, isTrue);
  });
}
