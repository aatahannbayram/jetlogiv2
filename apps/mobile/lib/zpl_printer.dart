import 'dart:convert';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Bluetooth yazıcı adresi `bt:<MAC ya da kimlik>|<ad>` biçiminde saklanır;
/// ağ yazıcısı düz IP'dir. İkisi aynı ayarda durur, yazdırma yolu buna göre
/// seçilir.
const kBluetoothPrinterPrefix = 'bt:';

bool isBluetoothPrinter(String host) =>
    host.trim().startsWith(kBluetoothPrinterPrefix);

String bluetoothPrinterHost({required String address, required String name}) =>
    '$kBluetoothPrinterPrefix$address|${name.replaceAll('|', ' ')}';

String _bluetoothAddress(String host) =>
    host.trim().substring(kBluetoothPrinterPrefix.length).split('|').first;

/// Kullanıcıya gösterilecek yazıcı adı: Bluetooth'ta cihaz adı, ağda adres.
String printerDisplayName(String host) {
  final h = host.trim();
  if (!isBluetoothPrinter(h)) return h;
  final parts = h.substring(kBluetoothPrinterPrefix.length).split('|');
  return parts.length > 1 && parts[1].isNotEmpty ? parts[1] : parts.first;
}

/// Telefonla eşleştirilmiş Bluetooth cihazları. İzin verilmezse ya da
/// Bluetooth kapalıysa boş döner.
Future<List<({String name, String address})>> pairedBluetoothPrinters() async {
  if (Platform.isAndroid) {
    final status = await Permission.bluetoothConnect.request();
    if (!status.isGranted) return const [];
  }
  if (!await PrintBluetoothThermal.bluetoothEnabled) return const [];
  final devices = await PrintBluetoothThermal.pairedBluetooths;
  return [for (final d in devices) (name: d.name, address: d.macAdress)];
}

Future<void> _sendZplBluetooth(String host, String zpl) async {
  if (Platform.isAndroid) {
    final status = await Permission.bluetoothConnect.request();
    if (!status.isGranted) {
      throw const SocketException('Bluetooth izni verilmedi');
    }
  }
  final connected = await PrintBluetoothThermal.connect(
    macPrinterAddress: _bluetoothAddress(host),
  );
  if (!connected)
    throw const SocketException('Bluetooth yazıcıya bağlanılamadı');
  try {
    final ok = await PrintBluetoothThermal.writeBytes(utf8.encode(zpl));
    if (!ok) throw const SocketException('Bluetooth yazıcıya yazılamadı');
  } finally {
    await PrintBluetoothThermal.disconnect;
  }
}

/// ZPL'i yazıcıya ham olarak gönderir: Bluetooth yazıcıda eşleşmiş cihaza,
/// ağ yazıcısında standart 9100 portuna.
/// [host] `192.168.1.50`, `192.168.1.50:6101` ya da `bt:…` biçiminde olabilir.
/// Bağlantı kurulamazsa [SocketException] fırlatır.
Future<void> sendZplToPrinter(String host, String zpl) async {
  if (isBluetoothPrinter(host)) return _sendZplBluetooth(host, zpl);
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
