import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/agency_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../label_pdf.dart';
import '../label_print_sheet.dart';
import '../zpl_printer.dart';
import 'sube_widgets.dart';

/// Seçilen gönderilerin etiketlerini basar: web sürümünde PDF olarak
/// telefonun yazdırma menüsüne, uygulamada ağdaki Zebra yazıcıya. Basılan
/// adet döner; vazgeçilir ya da basılamazsa null (kullanıcıya bildirilir).
Future<int?> printShipmentLabels(
  BuildContext context,
  BranchWorkspace branch,
  List<String> shipmentIds,
) async {
  final l = context.l10n;
  if (shipmentIds.isEmpty) return null;
  if (!kIsWeb && branch.printerHost.isEmpty) {
    subeSnack(context, l.prepPrinterMissing);
    return null;
  }
  try {
    final rows = await branch.printRows(shipmentIds);
    if (!context.mounted) return null;
    if (kIsWeb) {
      final pdf = await buildLabelPdfWithAppFont([
        for (final row in rows) labelSheetFromShipmentRow(row),
      ]);
      if (!context.mounted) return null;
      if (!await showLabelPdfSheet(context, pdf, rows.length)) return null;
    } else {
      for (final row in rows) {
        await sendZplToPrinter(branch.printerHost, shipmentLabelZpl(row));
      }
    }
    if (context.mounted) subeSnack(context, l.prepPrinted(rows.length));
    return rows.length;
  } on AgencyApiException catch (e) {
    if (context.mounted) {
      subeSnack(context, e.serverMessage ?? l.reportFailedLoad);
    }
  } catch (_) {
    if (context.mounted) {
      subeSnack(
        context,
        kIsWeb
            ? l.reportFailedLoad
            : l.prepPrinterDown(printerDisplayName(branch.printerHost)),
      );
    }
  }
  return null;
}
