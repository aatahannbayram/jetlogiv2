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
