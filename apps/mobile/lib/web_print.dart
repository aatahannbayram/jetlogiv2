// PDF'i tarayıcının paylaş/yazdır akışına verir. Yalnız web'de anlamlı;
// mobilde etiket ZPL ile doğrudan yazıcıya gider (bkz. zpl_printer.dart).
export 'web_print_stub.dart' if (dart.library.js_interop) 'web_print_web.dart';
