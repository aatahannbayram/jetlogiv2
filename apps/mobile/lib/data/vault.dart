import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain / Keystore. Access JWT, refresh, DB passphrase, installationId.
class Vault {
  Vault({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _dbKey = 'dg.db.key';
  static const _install = 'dg.installation_id';
  static const _access = 'dg.access_token';
  static const _refresh = 'dg.refresh_token';
  static const _accessExp = 'dg.access_exp';
  static const _refreshExp = 'dg.refresh_exp';

  Future<String> databaseKeyHex() async {
    final existing = await _storage.read(key: _dbKey);
    if (existing != null && existing.length == 64) return existing;
    final hex = _randomHex(32);
    await _put(_dbKey, hex);
    return hex;
  }

  Future<String> installationId() async {
    final existing = await _storage.read(key: _install);
    if (existing != null && existing.length == 36) return existing;
    final id = newUuid();
    await _put(_install, id);
    return id;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
    required DateTime refreshExpiresAt,
  }) async {
    await _put(_access, accessToken);
    await _put(_refresh, refreshToken);
    await _put(_accessExp, accessExpiresAt.toUtc().toIso8601String());
    await _put(_refreshExp, refreshExpiresAt.toUtc().toIso8601String());
  }

  /// iOS keychain sometimes returns -25299 (duplicate) on write.
  /// Delete-then-write recovers without blocking boot.
  Future<void> _put(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> get accessToken async => _storage.read(key: _access);

  Future<String?> get refreshToken async => _storage.read(key: _refresh);

  Future<void> clearTokens() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _accessExp);
    await _storage.delete(key: _refreshExp);
  }

  static const _onboard = 'dg.onboard.v2';
  static const _tips = 'dg.tips.v1';
  static const _subeOnboard = 'dg.sube.onboard.v1';
  static const _taskWatermark = 'dg.task.watermark';
  static const _locale = 'dg.ui.locale';
  static const _dark = 'dg.ui.dark';
  static const _notify = 'dg.ui.notify';
  static const _shiftOpen = 'dg.shift.open';
  static const _shiftStarted = 'dg.shift.started';

  Future<String?> get locale async => _storage.read(key: _locale);

  Future<void> saveLocale(String value) => _put(_locale, value);

  Future<bool?> get darkMode async {
    final v = await _storage.read(key: _dark);
    if (v == null) return null;
    return v == '1';
  }

  Future<void> saveDarkMode(bool value) => _put(_dark, value ? '1' : '0');

  Future<bool?> get notifyEnabled async {
    final v = await _storage.read(key: _notify);
    if (v == null) return null;
    return v == '1';
  }

  Future<void> saveNotifyEnabled(bool value) =>
      _put(_notify, value ? '1' : '0');

  Future<String?> get taskWatermark async => _storage.read(key: _taskWatermark);

  Future<void> saveTaskWatermark(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _taskWatermark);
    } else {
      await _put(_taskWatermark, value);
    }
  }

  Future<bool> get onboardSeen async =>
      (await _storage.read(key: _onboard)) == '1';

  Future<void> markOnboardSeen() => _put(_onboard, '1');

  Future<bool> get tipsSeen async => (await _storage.read(key: _tips)) == '1';

  Future<void> markTipsSeen() => _put(_tips, '1');

  Future<bool> get subeOnboardSeen async =>
      (await _storage.read(key: _subeOnboard)) == '1';

  Future<void> markSubeOnboardSeen() => _put(_subeOnboard, '1');

  Future<bool> get shiftIsOpen async =>
      (await _storage.read(key: _shiftOpen)) == '1';

  Future<DateTime?> get shiftStartedAt async {
    final raw = await _storage.read(key: _shiftStarted);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveShift({required bool open, DateTime? startedAt}) async {
    await _put(_shiftOpen, open ? '1' : '0');
    if (open && startedAt != null) {
      await _put(_shiftStarted, startedAt.toIso8601String());
    } else {
      await _storage.delete(key: _shiftStarted);
    }
  }

  static const _notifRead = 'dg.notif.read';
  static const _notifGone = 'dg.notif.gone';
  static const _notifCap = 200;

  Future<Set<String>> get readNotificationIds async =>
      _idSet(await _storage.read(key: _notifRead));

  Future<Set<String>> get dismissedNotificationIds async =>
      _idSet(await _storage.read(key: _notifGone));

  Future<String?> readSecret(String key) => _storage.read(key: key);

  Future<void> writeSecret(String key, String value) => _put(key, value);

  Future<void> deleteSecret(String key) => _storage.delete(key: key);

  Future<void> saveNotificationState({
    required Set<String> readIds,
    required Set<String> dismissedIds,
  }) async {
    await _put(_notifRead, _joinIds(readIds));
    await _put(_notifGone, _joinIds(dismissedIds));
  }

  static Set<String> _idSet(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    return {for (final p in raw.split(',')) if (p.isNotEmpty) p};
  }

  static String _joinIds(Set<String> ids) {
    if (ids.length <= _notifCap) return ids.join(',');
    return ids.skip(ids.length - _notifCap).join(',');
  }

  static String newUuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  static String _randomHex(int bytes) {
    final r = Random.secure();
    return List<int>.generate(
      bytes,
      (_) => r.nextInt(256),
    ).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }
}
