/// Şube ekranlarının JetDiji uç kapsamı (branch.yaml 1.2.0, courier.yaml
/// 1.4.0; 27.10.2026). `false` olan ekran canlıda görünür ama veri yerine
/// dürüst boş durum gösterir (`DgPendingBackend`); demo derlemesinde örnek
/// veriyle dolar. Uç geldiğinde yalnız buradaki bayrak açılır.
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
  static const courierDevice = false;

  /// Plaka, kurye detay ucu, yeni kurye/davet: yok.
  static const courierCreate = false;

  /// Kart yenile / iptal: yok (aynı gün aynı token).
  static const cardRenew = false;

  /// GET branch/invoices: schemaReady=false, liste hep boş.
  static const invoices = false;

  /// compliance contracts/documents: NOT_AVAILABLE.
  static const partnerDocuments = false;

  /// Dağıtım planlama talebi: uç yok.
  static const distributionPlanning = false;

  /// Gün sonu kapatma: uç yok.
  static const endOfDayClose = false;

  /// Şube stok sayaçları: uç yok.
  static const branchStockCounters = false;

  /// Gönderiye bağlı olmayan merkez transferi (ekipman, evrak, kart): yok.
  static const freeTransferItems = false;

  /// Ürün eşleştirme, manifesto: yok.
  static const productMatch = false;

  /// Serbest tarih aralığı (performans yalnız today/7d/30d).
  static const customDateRange = false;
}
