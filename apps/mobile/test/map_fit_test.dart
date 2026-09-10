import 'package:dijigoo_kurye/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapRouteFitPadding alt sheet için alt pay bırakır', () {
    const height = 800.0;
    const topInset = 47.0;
    final pad = mapRouteFitPadding(height: height, topInset: topInset);
    expect(pad.left, 44);
    expect(pad.right, 44);
    expect(pad.top, topInset + 64);
    expect(pad.bottom, height * 0.42 + 12);
    expect(pad.bottom, greaterThan(height * 0.4));
  });
}
