import 'dart:convert';

import 'package:dijigoo_kurye/api/branch_models.dart';
import 'package:dijigoo_kurye/label_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gönderi satırı ZPL etiketiyle aynı alanları taşır', () {
    final sheet = labelSheetFromShipmentRow({
      'primaryBarcode': 'JD123456',
      'recipientName': 'Şükrü Öğütçü',
      'referenceNo': 'DEMOANK001',
      'customer': {'name': 'Pluxee'},
      'destination': {
        'addressLine': 'İnönü Cad. No:5',
        'neighborhood': 'Kızılay',
        'districtName': 'Çankaya',
        'cityName': 'Ankara',
      },
    });
    expect(sheet.barcode, 'JD123456');
    expect(sheet.heading, 'Pluxee');
    expect(sheet.title, 'Şükrü Öğütçü');
    expect(sheet.lines, ['İnönü Cad. No:5', 'Kızılay / Çankaya / Ankara']);
    expect(sheet.footer, 'DEMOANK001');
  });

  test('barkod yoksa gönderi numarası basılır', () {
    final sheet = labelSheetFromShipmentRow({'shipmentNumber': 'S-9'});
    expect(sheet.barcode, 'S-9');
    expect(sheet.lines, isEmpty);
  });

  test('her etiket 100×75 mm ayrı sayfa, Türkçe yazı tipiyle', () async {
    final pdf = await buildLabelPdfWithAppFont([
      labelSheetFromPrintable(
        const PrintableLabel(id: 'a', barcode: 'LBL-0001', typeCode: 'CASE'),
      ),
      labelSheetFromShipmentRow({
        'primaryBarcode': 'JD123456',
        'recipientName': 'Şükrü Öğütçü',
        'destination': {'addressLine': 'İnönü Cad.'},
      }),
    ]);
    final text = latin1.decode(pdf);
    expect(text.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(text).length, 2);
    // 100 mm × 75 mm = 283.46 × 212.6 pt
    expect(text, contains('283.46'));
    expect(text, contains('/FontFile2'));
  });
}
