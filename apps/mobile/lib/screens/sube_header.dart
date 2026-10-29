import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../brand.dart';
import '../l10n.dart';
import '../session.dart';
import '../shell_nav.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_inbox_screen.dart';

/// Şube ana sekmelerinin ortak üst barı (mockup): solda ana logo, sağda
/// okunmamış rozetli zil ve baş harf avatarı (Profil'e götürür).
class SubeHeaderBar extends ConsumerWidget implements PreferredSizeWidget {
  const SubeHeaderBar({super.key, this.actions = const []});

  /// Zilden önce gösterilecek ek düğmeler (ör. yenile).
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final unread = (s.branch.inbox ?? const []).where((i) => !i.read).length;
    final name = s.agencyUser?.fullName ?? '';
    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      title: DijigooWordmark(height: 34, onDark: Dg.dark),
      actions: [
        ...actions,
        Semantics(
          button: true,
          label: unread > 0 ? '${l.subeInboxTitle}, $unread' : l.subeInboxTitle,
          excludeSemantics: true,
          child: IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SubeInboxScreen()),
            ),
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
              onTap: () => ref.read(subeNavProvider).go(SubeNav.profile),
              child: InitialsAvatar(name: name.isEmpty ? '?' : name, size: 36),
            ),
          ),
        ),
      ],
    );
  }
}
