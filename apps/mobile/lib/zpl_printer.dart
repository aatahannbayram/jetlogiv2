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
