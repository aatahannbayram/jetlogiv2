import 'api/agency_models.dart';

/// Barkodun okutulduğu işlem bağlamı. Her modülün ayrı tarama kodu yok:
/// kamera, manuel giriş ve HID okuyucu aynı [ScanRouter]'a düşer, bağlam
/// barkodu doğru işleme yönlendirir.
enum ScanContext {
  /// Gönderi sorgu — okutulanı listede bul.
  lookup,

  /// Kurye zimmeti — gönderiyi atama seçimine ekle.
  assign,

  /// Kuryeden dönen gönderiyi şubeye teslim al.
  courierReturn,

  /// Gelen transfer / koli kalemini şubeye kabul et.
  stockIn,

  /// Açık stok sayımına ekle.
  count,

  /// Merkeze sevk taslağına ekle.
  dispatch,
}

enum ScanTone { ok, warn, bad }

class ScanOutcome {
  const ScanOutcome(this.tone, this.title, [this.detail = '']);

  const ScanOutcome.ok(String title, [String detail = ''])
    : this(ScanTone.ok, title, detail);
  const ScanOutcome.warn(String title, [String detail = ''])
    : this(ScanTone.warn, title, detail);
  const ScanOutcome.bad(String title, [String detail = ''])
    : this(ScanTone.bad, title, detail);

  final ScanTone tone;
  final String title;
  final String detail;

  bool get ok => tone == ScanTone.ok;
}

typedef ScanHandler = Future<ScanOutcome> Function(String code);

class ScanRouter {
  final _handlers = <ScanContext, ScanHandler>{};

  void register(ScanContext context, ScanHandler handler) {
    _handlers[context] = handler;
  }

  /// Hiç fırlatmaz: sunucu reddi ya da ağ hatası da okutan kişiye
  /// gösterilecek bir [ScanOutcome]'dur.
  Future<ScanOutcome> handle(ScanContext context, String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return const ScanOutcome.bad('Kod okunamadı');
    final handler = _handlers[context];
    if (handler == null) {
      return const ScanOutcome.bad('Bu ekranda okutma yapılamıyor');
    }
    try {
      return await handler(code);
    } on AgencyApiException catch (e) {
      return ScanOutcome.bad(e.serverMessage ?? scanErrorText(e.code), code);
    } catch (_) {
      return ScanOutcome.bad('Bağlantı kurulamadı', code);
    }
  }
}

/// Sunucu Türkçe `error.message` göndermediğinde gösterilecek kısa metin.
String scanErrorText(String code) => switch (code) {
  'SHIPMENT_NOT_FOUND' ||
  'BRANCH_SHIPMENT_NOT_FOUND' => 'Gönderi bu iş ortağında bulunamadı',
  'FORBIDDEN' => 'Bu işlem için yetkiniz yok',
  'COUNT_OPERATION_REJECTED' => 'Sayım bu işlemi kabul etmedi',
  'AGENCY_REQUEST_FAILED' => 'Bağlantı kurulamadı',
  'DATE_INVALID' => 'Tarih geçersiz.',
  'RANGE_INVALID' => 'Tarih aralığı geçersiz.',
  'RANGE_TOO_LONG' => 'Aralık en fazla 92 gün olabilir.',
  'COURIER_NOT_FOUND' => 'Kurye bu iş ortağında bulunamadı.',
  _ => 'İşlem yapılamadı ($code)',
};
