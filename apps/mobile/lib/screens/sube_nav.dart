import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Şube kabuğunun sekme sırası (Hande: Ana Sayfa / Gönderiler / Kuryeler /
/// İşlemler / Profil).
abstract final class SubeTab {
  static const home = 0;
  static const shipments = 1;
  static const couriers = 2;
  static const ops = 3;
  static const profile = 4;
}

/// Açık sekme. Dashboard kartları ve hızlı işlemler buradan sekme değiştirir.
final subeTabProvider = StateProvider<int>((_) => SubeTab.home);

/// Gönderiler'e "şu filtreyle aç" isteği. Gönderiler ekranı okuyup
/// uyguladıktan sonra null'a çeker.
final subeShipmentFilterProvider = StateProvider<String?>((_) => null);

void openShipmentsWith(WidgetRef ref, String filter) {
  ref.read(subeShipmentFilterProvider.notifier).state = filter;
  ref.read(subeTabProvider.notifier).state = SubeTab.shipments;
}
