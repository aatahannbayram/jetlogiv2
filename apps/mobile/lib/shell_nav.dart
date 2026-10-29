import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alt sekme konumu — Home'daki zil/"Tümü" Bildirimler sekmesine geçer,
/// ikinci bir [NotifScreen] yığmaz.
final shellNavProvider = ChangeNotifierProvider<ShellNav>((ref) => ShellNav());

class ShellNav extends ChangeNotifier {
  int index = 0;

  static const home = 0;
  static const route = 1;
  static const scan = 2;
  static const notif = 3;
  static const menu = 4;

  void go(int i) {
    if (index == i) return;
    index = i;
    notifyListeners();
  }
}

/// Şube alt sekmesi ve gönderi filtresi — ana sayfadaki kutular ilgili
/// sekmeye (ve filtreye) bununla geçer.
final subeNavProvider = ChangeNotifierProvider<SubeNav>((ref) => SubeNav());

class SubeNav extends ChangeNotifier {
  int index = 0;

  /// Gönderiler sekmesinin açılacağı filtre; okununca sıfırlanır.
  String? pendingFilter;

  // Hande'nin sabit alt menüsü: Ana Sayfa / Gönderiler / Kuryeler /
  // İşlemler / Profil. Stok & Zimmet İşlemler'in altında.
  static const home = 0;
  static const shipments = 1;
  static const couriers = 2;
  static const ops = 3;
  static const profile = 4;

  void go(int i, {String? filter}) {
    index = i;
    pendingFilter = filter;
    notifyListeners();
  }

  String? takeFilter() {
    final f = pendingFilter;
    pendingFilter = null;
    return f;
  }
}
