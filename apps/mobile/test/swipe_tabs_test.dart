import 'package:dijigoo_kurye/motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hızlı sola kaydırma sonraki, sağa kaydırma önceki sekme', () {
    expect(SwipeTabs.target(0, 5, -800, const {}), 1);
    expect(SwipeTabs.target(1, 5, 800, const {}), 0);
  });
  test('yavaş hareket ve kenarlar sekme değiştirmez', () {
    expect(SwipeTabs.target(1, 5, -100, const {}), isNull);
    expect(SwipeTabs.target(0, 5, 800, const {}), isNull);
    expect(SwipeTabs.target(4, 5, -800, const {}), isNull);
  });
  test('atlanan sekme geçilir', () {
    expect(SwipeTabs.target(1, 5, -800, const {2}), 3);
    expect(SwipeTabs.target(3, 5, 800, const {2}), 1);
  });
}
