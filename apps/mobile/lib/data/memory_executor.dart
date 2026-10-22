// Bellek içi drift bağlantısı: mobilde NativeDatabase, web'de stub.
// `drift/native.dart` sqlite3 FFI çektiği için web derlemesine girmemeli.
export 'memory_executor_stub.dart'
    if (dart.library.io) 'memory_executor_io.dart';
