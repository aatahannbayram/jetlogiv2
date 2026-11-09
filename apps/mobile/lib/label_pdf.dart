import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'api/branch_models.dart';

/// Web sürümünde ZPL yerine basılan etiket: tarayıcı Bluetooth'a ve ham
/// TCP'ye erişemez, PDF telefonun yazdırma menüsüyle (AirPrint) basılır.
/// Ölçü ZPL etiketiyle aynı: 100×75 mm.
class LabelSheet {
  const LabelSheet({
    required this.barcode,
    this.heading = '',
    this.title = '',
    this.lines = const [],
    this.footer = '',
  });

  final String barcode;
  final String heading;
  final String title;
  final List<String> lines;
  final String footer;
}

LabelSheet labelSheetFromPrintable(PrintableLabel label) => LabelSheet(
  barcode: label.barcode,
  heading: label.typeCode,
  footer: label.shipmentNumber,
);

/// [shipmentLabelZpl] ile aynı alanlar (`preparation/print-rows` satırı).
LabelSheet labelSheetFromShipmentRow(Map<String, dynamic> row) {
  String clean(Object? v) => '${v ?? ''}'.trim();
  final dest = row['destination'] is Map ? row['destination'] as Map : const {};
  final customer = row['customer'] is Map ? row['customer'] as Map : const {};
  final place = [
    clean(dest['neighborhood']),
    clean(dest['districtName']),
    clean(dest['cityName']),
  ].where((e) => e.isNotEmpty).join(' / ');
  return LabelSheet(
    barcode: clean(row['primaryBarcode'] ?? row['shipmentNumber']),
    heading: clean(customer['name']),
    title: clean(row['recipientName']),
    lines: [
      clean(dest['addressLine']),
      place,
    ].where((e) => e.isNotEmpty).toList(),
    footer: clean(row['referenceNo']),
  );
}

const _labelFormat = PdfPageFormat(
  100 * PdfPageFormat.mm,
  75 * PdfPageFormat.mm,
  marginAll: 4 * PdfPageFormat.mm,
);

/// Her etiket bir sayfa. [font] Türkçe harfleri (ş, ğ, İ) içermeli.
Future<Uint8List> buildLabelPdf(
  List<LabelSheet> sheets, {
  required ByteData font,
}) async {
  final ttf = pw.Font.ttf(font);
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: ttf, bold: ttf),
  );
  for (final s in sheets) {
    doc.addPage(
      pw.Page(
        pageFormat: _labelFormat,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (s.heading.isNotEmpty)
              pw.Text(s.heading, style: const pw.TextStyle(fontSize: 11)),
            if (s.title.isNotEmpty)
              pw.Text(
                s.title,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            for (final line in s.lines)
              pw.Text(
                line,
                maxLines: 2,
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.Spacer(),
            if (s.barcode.isNotEmpty)
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: s.barcode,
                height: 22 * PdfPageFormat.mm,
                textStyle: const pw.TextStyle(fontSize: 10),
              ),
            if (s.footer.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  s.footer,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

/// Uygulamanın kendi yazı tipiyle (Manrope, teslim v1.1 sabit kesim) PDF.
Future<Uint8List> buildLabelPdfWithAppFont(List<LabelSheet> sheets) async =>
    buildLabelPdf(
      sheets,
      font: await rootBundle.load('assets/fonts/Manrope-Regular.ttf'),
    );
