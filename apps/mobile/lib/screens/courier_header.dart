import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../brand.dart';
import '../l10n.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile_screen.dart';

/// Kurye ana sekmelerinin ortak üst barı (şube [SubeHeaderBar] ile aynı
/// dil): solda ana logo, sağda isteğe bağlı durum, okunmamış rozetli zil
/// (Bildirimler sekmesine geçer) ve profil avatarı.
class CourierHeaderBar extends ConsumerWidget implements PreferredSizeWidget {
  const CourierHeaderBar({super.key, this.actions = const []});

  /// Zilden önce gösterilecek ek öğeler (ör. çevrimiçi durumu).
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final unread = s.unreadNotifCount;
    final name = s.courier.fullName;
    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      title: DijigooWordmark(height: 34, onDark: Dg.dark),
      actions: [
        ...actions,
        Semantics(
          button: true,
          label: unread > 0 ? '${l.notifications}, $unread' : l.notifications,
          excludeSemantics: true,
          child: IconButton(
            key: const Key('courier-header-bell'),
            onPressed: () => ref.read(shellNavProvider).go(ShellNav.notif),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(LucideIcons.bell, size: 22, color: Dg.text1),
                if (unread > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Dg.badgeRed,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Dg.bg, width: 2),
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontFamily: Dg.sans,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 2),
          child: Semantics(
            button: true,
            label: l.openProfile,
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('courier-header-avatar'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              ),
              child: InitialsAvatar(
                name: name.isEmpty ? '?' : name,
                photoUrl: s.courier.photoUrl,
                size: 36,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
