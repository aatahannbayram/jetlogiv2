import 'package:dijigoo_kurye/l10n.dart';
import 'package:dijigoo_kurye/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const l = L10n('tr');
  final now = DateTime(2026, 11, 19, 10, 0);

  test('tarih yoksa etiket yok', () {
    expect(plannedDateLabel(null, l, now: now), isNull);
  });

  test('bugün yalnız saat, yarın "Yarın", sonrası gün ve ay', () {
    expect(plannedDateLabel(DateTime(2026, 11, 19, 14, 5), l, now: now), '14:05');
    expect(
      plannedDateLabel(DateTime(2026, 11, 20, 9, 0), l, now: now),
      'Yarın 09:00',
    );
    expect(
      plannedDateLabel(DateTime(2026, 11, 24, 16, 30), l, now: now),
      '24 Kasım 16:30',
    );
  });
}
