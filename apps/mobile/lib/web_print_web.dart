import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Dokunuşun içinde, `await`'ten önce çağrılmalı: iOS Safari kullanıcı
/// hareketi bittikten sonra açılan paylaşım menüsünü ve pencereyi engeller.
/// iPhone'da paylaşım menüsü açılır (oradan Yazdır → AirPrint); paylaşım
/// yoksa PDF yeni sekmede açılır.
void presentPdf(Uint8List pdf, String filename) {
  final file = web.File(
    [pdf.toJS].toJS,
    filename,
    web.FilePropertyBag(type: 'application/pdf'),
  );
  final data = web.ShareData(files: [file].toJS);
  final nav = web.window.navigator;
  if (nav.canShare(data)) {
    // Kullanıcı menüyü kapatırsa söz reddedilir; yutulur.
    nav.share(data).toDart.ignore();
    return;
  }
  web.window.open(web.URL.createObjectURL(file), '_blank');
}
