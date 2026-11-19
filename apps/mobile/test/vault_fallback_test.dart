import 'package:dijigoo_kurye/data/vault.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Güvensiz web bağlamındaki (WebCrypto yok) davranış: her işlem hata verir.
class _BrokenStorage extends FlutterSecureStorage {
  const _BrokenStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw UnsupportedError('crypto.subtle');

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw UnsupportedError('crypto.subtle');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw UnsupportedError('crypto.subtle');
}

void main() {
  test('güvenli depo yoksa vault bellekte çalışır, hata fırlatmaz', () async {
    final v = Vault(storage: const _BrokenStorage());
    await v.writeSecret('dg.remember', '1');
    expect(await v.readSecret('dg.remember'), '1');
    await v.deleteSecret('dg.remember');
    expect(await v.readSecret('dg.remember'), isNull);
    await v.markOnboardSeen();
    expect(await v.onboardSeen, isTrue);
  });
}
