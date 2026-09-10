import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../brand.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'depo_screen.dart';
import 'earnings_screen.dart';
import 'envanter_screen.dart';
import 'eod_screen.dart';
import 'kyc_screen.dart';
import 'profile_screen.dart';
import 'support_screen.dart';
import 'sync_screen.dart';
import 'tara_screen.dart';
import 'training_screen.dart';
import 'zimmet_screen.dart';

enum _ChipTone { accent, mute }

typedef _MenuRow = ({
  String label,
  IconData icon,
  String? badge,
  _ChipTone tone,
  Widget Function() open,
});

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final pending = s.outbox.events.where((e) => e.pending).length;
    final trainingOpen = s.trainingModules.where((m) => !m.completed).length;

    final daily = <_MenuRow>[
      (
        label: l.myCustody,
        icon: LucideIcons.qrCode,
        badge: null,
        tone: _ChipTone.accent,
        open: () => const TaraScreen(),
      ),
      (
        label: l.branchHandover,
        icon: LucideIcons.building2,
        badge: null,
        tone: _ChipTone.accent,
        open: () => const ZimmetScreen(mode: 'sube'),
      ),
      (
        label: l.depotPickup,
        icon: LucideIcons.warehouse,
        badge: null,
        tone: _ChipTone.accent,
        open: () => const DepoScreen(),
      ),
      (
        label: l.myInventory,
        icon: LucideIcons.package,
        badge: s.inventoryPending > 0 ? '${s.inventoryPending}' : null,
        tone: _ChipTone.accent,
        open: () => const EnvanterScreen(),
      ),
    ];

    final other = <_MenuRow>[
      (
        label: l.supportTicket,
        icon: LucideIcons.lifeBuoy,
        badge: s.tickets.isEmpty ? null : '${s.tickets.length}',
        tone: _ChipTone.mute,
        open: () => const SupportScreen(),
      ),
      (
        label: l.sendData,
        icon: LucideIcons.uploadCloud,
        badge: pending > 0 ? '$pending' : null,
        tone: _ChipTone.mute,
        open: () => const SyncScreen(),
      ),
      (
        label: l.eodTitle,
        icon: LucideIcons.moon,
        badge: null,
        tone: _ChipTone.mute,
        open: () => const EodScreen(),
      ),
      (
        label: l.trainingTitle,
        icon: LucideIcons.graduationCap,
        badge: trainingOpen > 0 ? '$trainingOpen' : null,
        tone: _ChipTone.mute,
        open: () => const TrainingScreen(),
      ),
    ];

    final account = <_MenuRow>[
      (
        label: l.myPerformance,
        icon: LucideIcons.trendingUp,
        badge: null,
        tone: _ChipTone.mute,
        open: () => const EarningsScreen(),
      ),
      (
        label: l.identityCheck,
        icon: LucideIcons.badgeCheck,
        badge: null,
        tone: _ChipTone.mute,
        open: () => const KycScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: Dg.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Dg.s20, Dg.s12, Dg.s20, 108),
          children: [
            Appear(child: DijigooWordmark(height: 22, onDark: Dg.dark)),
            const SizedBox(height: Dg.s28),
            _ProfileCard(session: s),
            const SizedBox(height: Dg.s28),
            _Section(title: l.menuDaily, items: daily, start: 0),
            const SizedBox(height: Dg.s28),
            _Section(title: l.menuOther, items: other, start: daily.length),
            const SizedBox(height: Dg.s28),
            _Section(title: l.account, items: account, start: 0),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = session.courier;
    final meta = session.panelLoggedIn
        ? l.panelSessionOn
        : session.lastPanelError == SessionController.panelSessionExpired
        ? l.panelSessionOff
        : l.openProfile;
    final expired =
        session.lastPanelError == SessionController.panelSessionExpired &&
        !session.panelLoggedIn;

    return Pressable(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
        );
      },
      child: _Sheet(
        child: Padding(
          padding: const EdgeInsets.all(Dg.s16),
          child: Row(
            children: [
              InitialsAvatar(name: c.fullName, photoUrl: c.photoUrl, size: 52),
              const SizedBox(width: Dg.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName, style: Dg.typeH2()),
                    const SizedBox(height: Dg.s4),
                    Text(
                      '${session.plate} · ${c.vehicle}',
                      style: Dg.typeCaption(),
                    ),
                    const SizedBox(height: Dg.s4),
                    Text(
                      meta,
                      key: session.panelLoggedIn
                          ? const Key('panel-session-chip')
                          : expired
                          ? const Key('panel-session-expired')
                          : null,
                      style: Dg.typeCaption(
                        color: expired ? Dg.bad : Dg.text2,
                      ),
                    ),
                  ],
                ),
              ),
              DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.text3),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.start,
  });

  final String title;
  final List<_MenuRow> items;
  final int start;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Dg.s4, bottom: Dg.s8),
          child: Text(
            localeUpper(title, context.l10n.code),
            style: Dg.typeOverline(),
          ),
        ),
        _Sheet(
          child: Column(
            children: [
              for (final (i, m) in items.indexed) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 64),
                    child: Container(height: 0.5, color: Dg.stroke),
                  ),
                _MenuTile(row: m, index: start + i),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.row, required this.index});

  final _MenuRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = row.tone == _ChipTone.accent;
    final tile = Pressable(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => row.open()),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Dg.menuRow),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dg.s16),
          child: Row(
            children: [
              DgIconChip(
                icon: row.icon,
                accent: accent,
                size: 36,
              ),
              const SizedBox(width: Dg.s12),
              Expanded(
                child: Text(row.label, style: Dg.typeBody()),
              ),
              if (row.badge != null) ...[
                _Badge(row.badge!),
                const SizedBox(width: Dg.s8),
              ],
              DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.text3),
            ],
          ),
        ),
      ),
    );
    if (index > 5 || MediaQuery.disableAnimationsOf(context)) return tile;
    return tile
        .animate(delay: (30 * index).ms)
        .fadeIn(duration: 200.ms, curve: Curves.easeOut)
        .slideY(begin: 0.12, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dg.s8, vertical: 2),
      decoration: BoxDecoration(
        color: Dg.warnSoft,
        borderRadius: BorderRadius.circular(Dg.rSm),
      ),
      child: Text(
        value,
        style: Dg.typeNum(size: 12, weight: FontWeight.w600, color: Dg.warn),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Dg.surface1,
        borderRadius: BorderRadius.circular(Dg.rLg),
        border: Border(top: BorderSide(color: Dg.hairline, width: 0.5)),
      ),
      child: child,
    );
  }
}
