import 'dart:convert';
import 'dart:io';

/// ZPL'i ağdaki Zebra yazıcıya ham olarak gönderir (standart 9100 portu).
/// [host] `192.168.1.50` ya da `192.168.1.50:6101` biçiminde olabilir.
/// Bağlantı kurulamazsa [SocketException] fırlatır.
Future<void> sendZplToPrinter(String host, String zpl) async {
  final parts = host.trim().split(':');
  final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
  final socket = await Socket.connect(
    parts.first,
    port,
    timeout: const Duration(seconds: 5),
  );
  try {
    socket.add(utf8.encode(zpl));
    await socket.flush();
  } finally {
    await socket.close();
  }
}

/// `preparation/print-rows` satırından 100×75 mm gönderi etiketi (203 dpi).
/// `^CI28` Türkçe karakterler için UTF-8'i açar; `^FH` ile kaçış yok, bu
/// yüzden ZPL denetim karakterleri (`^`, `~`) metinden atılır.
String shipmentLabelZpl(Map<String, dynamic> row) {
  String clean(Object? v) =>
      '${v ?? ''}'.replaceAll(RegExp(r'[\^~\r\n]'), ' ').trim();
  final dest = row['destination'] is Map ? row['destination'] as Map : const {};
  final customer = row['customer'] is Map ? row['customer'] as Map : const {};
  final barcode = clean(row['primaryBarcode'] ?? row['shipmentNumber']);
  final place = [
    clean(dest['neighborhood']),
    clean(dest['districtName']),
    clean(dest['cityName']),
  ].where((e) => e.isNotEmpty).join(' / ');
  return [
    '^XA',
    '^CI28',
    '^PW800',
    '^LL600',
    '^FO40,30^A0N,40,40^FD${clean(customer['name'])}^FS',
    '^FO40,85^A0N,56,56^FD${clean(row['recipientName'])}^FS',
    '^FO40,160^A0N,32,32^FB720,2,0,L^FD${clean(dest['addressLine'])}^FS',
    '^FO40,240^A0N,36,36^FD$place^FS',
    '^FO40,310^BY3^BCN,140,Y,N,N^FD$barcode^FS',
    if (clean(row['referenceNo']).isNotEmpty)
      '^FO40,520^A0N,28,28^FD${clean(row['referenceNo'])}^FS',
    '^XZ',
  ].join('\n');
}
