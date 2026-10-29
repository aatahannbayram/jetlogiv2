import 'dart:async';

import 'package:dio/dio.dart';

/// İsteğe Bearer eklenmesin (yenileme ucu refresh tokenını gövdede ister).
const kNoAuthExtra = 'dgNoAuth';

/// Bu istek bir kez yenilendi; ikinci 401'de yeniden denenmez.
const _retriedExtra = 'dgRetried';

/// JetDiji erişim tokenı 8 saat geçerli. Bir istek `401` dönünce girişte
/// alınan refresh tokenıyla yeni token alınır ve istek bir kez tekrarlanır
/// (kurye `courier-auth/refresh`, şube `agency-auth/refresh`).
///
/// Refresh tokenı tek kullanımlık olduğundan aynı anda tek yenileme yapılır;
/// eşzamanlı 401'ler aynı yenilemeyi bekler. Sunucu refresh tokenını
/// reddederse ([onRejected]) tokenlar silinir ve 401 olduğu gibi döner;
/// uygulama giriş ekranını açar. Ağ hatasında tokenlara dokunulmaz.
class TokenRefresher extends Interceptor {
  TokenRefresher({
    required this.dio,
    required this.refreshPath,
    required this.authPaths,
    required this.readRefreshToken,
    required this.onRefreshed,
    required this.onRejected,
  });

  final Dio dio;
  final String refreshPath;

  /// Giriş / SMS / çıkış gibi uçlar: buradan dönen 401 yenileme tetiklemez.
  final List<String> authPaths;
  final Future<String?> Function() readRefreshToken;
  final Future<void> Function(String accessToken, String? refreshToken)
  onRefreshed;
  final Future<void> Function() onRejected;

  Future<bool>? _running;

  bool _skips(RequestOptions options) =>
      options.extra[_retriedExtra] == true ||
      options.path.endsWith(refreshPath) ||
      authPaths.any(options.path.endsWith);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || _skips(options)) {
      return handler.next(err);
    }
    final refreshed = await (_running ??= _refresh().whenComplete(
      () => _running = null,
    ));
    if (!refreshed) return handler.next(err);
    options.extra[_retriedExtra] = true;
    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    final token = await readRefreshToken();
    if (token == null || token.isEmpty) return false;
    try {
      final res = await dio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': token},
        options: Options(extra: {kNoAuthExtra: true, _retriedExtra: true}),
      );
      final data = res.data?['data'];
      final access = data is Map ? data['accessToken'] as String? : null;
      if (access == null || access.isEmpty) {
        await onRejected();
        return false;
      }
      await onRefreshed(
        access,
        data is Map ? data['refreshToken'] as String? : null,
      );
      return true;
    } on DioException catch (e) {
      // 400/401: refresh tokenı geçersiz, kullanılmış ya da süresi dolmuş.
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) await onRejected();
      return false;
    }
  }
}
