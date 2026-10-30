/// Şube ekranlarının JetDiji uç kapsamı (branch.yaml 1.2.0, courier.yaml
/// 1.4.0; 27.10.2026). `false` olan ekran canlıda görünür ama veri yerine
/// dürüst boş durum gösterir (`DgPendingBackend`); demo derlemesinde örnek
/// veriyle dolar. Uç geldiğinde yalnız buradaki bayrak açılır.
///
/// "Yok" bölümündekiler için istemci önerilen sözleşmeye göre hazır
/// (docs/15, `api/branch_proposed_models.dart`). Bayrak kod değişmeden de
/// açılır: `--dart-define=BF_EOD_CLOSE=true` gibi.
abstract final class BranchFeatures {
  // ---- Var (canlı veri) ----
  /// GET branch/courier-map: konum, elde gönderiler, telefon.
  static const courierMap = true;

  /// GET branch/courier-jobs?shipmentId=: alıcı, adres, ürün, randevu,
  /// kurye, son 12 hareket. Telefon, müşteri, not, SLA yok.
  static const shipmentDetail = true;

  /// GET branch/training?targetType=BRANCH + ilerleme uçları.
  static const staffTraining = true;

  /// GET branch/compliance: belge kalemleri, durum, son kullanma.
  static const courierDocuments = true;

  /// POST branch/compliance/cards (+ verify). Yenile/iptal yok.
  static const courierCard = true;

  /// GET branch/counts: DRAFT/IN_PROGRESS/REVIEW/POSTED/CANCELLED.
  static const countReconciliation = true;

  /// GET branch/notifications: kategori, okunmamış toplamı.
  static const notificationCategories = true;

  // ---- Yok / taslak (boş durum) ----
  /// Kurye cihaz modeli, izinler: şube ucu yok.
  static const courierDevice = bool.fromEnvironment('BF_COURIER_DEVICE');

  /// Plaka, kurye detay ucu, yeni kurye/davet: yok.
  static const courierCreate = bool.fromEnvironment('BF_COURIER_CREATE');

  /// Kart yenile / iptal: yok (aynı gün aynı token).
  static const cardRenew = bool.fromEnvironment('BF_CARD_RENEW');

  /// GET branch/invoices: schemaReady=false, liste hep boş.
  static const invoices = bool.fromEnvironment('BF_INVOICES');

  /// compliance contracts/documents: NOT_AVAILABLE.
  static const partnerDocuments = bool.fromEnvironment('BF_PARTNER_DOCUMENTS');

  /// Dağıtım planlama talebi: uç yok.
  static const distributionPlanning = bool.fromEnvironment(
    'BF_DISTRIBUTION_PLANNING',
  );

  /// Gün sonu kapatma: uç yok.
  static const endOfDayClose = bool.fromEnvironment('BF_EOD_CLOSE');

  /// Şube stok sayaçları: uç yok.
  static const branchStockCounters = bool.fromEnvironment('BF_STOCK_COUNTERS');

  /// Gönderiye bağlı olmayan merkez transferi (ekipman, evrak, kart): yok.
  static const freeTransferItems = bool.fromEnvironment('BF_FREE_TRANSFER');

  /// Ürün eşleştirme, manifesto: yok.
  static const productMatch = bool.fromEnvironment('BF_PRODUCT_MATCH');

  /// Gönderiler listesinde gün seçimi (`branch/dispatch?date=`).
  static const shipmentDate = bool.fromEnvironment('BF_SHIPMENT_DATE');

  /// Serbest tarih aralığı (performans yalnız today/7d/30d).
  static const customDateRange = bool.fromEnvironment('BF_CUSTOM_RANGE');

  /// Şube destek hattı (E.164). Önerilen `agency.supportPhone` gelene kadar
  /// yedek: `--dart-define=SUBE_SUPPORT_PHONE=+90…`. Boşsa bekleme durumu.
  static const supportPhone = String.fromEnvironment('SUBE_SUPPORT_PHONE');
}
