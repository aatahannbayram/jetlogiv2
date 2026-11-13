import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/client.dart' show kAppVersion;
import '../brand.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_inbox_screen.dart';
import 'sube_more_screens.dart';
import 'sube_widgets.dart';

/// Profilim: kullanıcı, şube, rol/yetki, ayarlar ve çıkış.
class SubeProfileScreen extends ConsumerWidget {
  const SubeProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final user = s.agencyUser;
    final caps = s.branch.capabilities;
    final roles = [
      for (final r in user?.roles ?? const [])
        (l.isEn ? r.nameEn : r.nameTr) ?? r.code,
    ];
    final supportPhone = user?.agency.supportPhone;
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: Text(l.subeTabProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Appear(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Dg.surface1,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Dg.hairline),
              ),
              child: Row(
                children: [
                  InitialsAvatar(name: user?.fullName ?? '?', size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '',
                          style: Dg.typeH2(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.agency.name ?? '',
                          style: Dg.typeLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (caps.operate)
                              StatusChip(
                                label: l.profileCanOperate,
                                tone: 'lime',
                              ),
                            if (caps.manage)
                              StatusChip(
                                label: l.profileCanManage,
                                tone: 'lime',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SubeOverline(l.profileUser),
          SubeGroup(
            children: [
              _InfoRow(
                icon: LucideIcons.mail,
                label: l.profileEmail,
                value: user?.email ?? '—',
              ),
              _InfoRow(
                icon: LucideIcons.badgeCheck,
                label: l.profileRole,
                value: roles.isEmpty ? '—' : roles.join(', '),
              ),
            ],
          ),
          SubeOverline(l.profileBranch),
          SubeGroup(
            children: [
              if (supportPhone != null && supportPhone.isNotEmpty)
                SubeNavTile(
                  icon: LucideIcons.phone,
                  label: l.supportLine,
                  subtitle: supportPhone,
                  onTap: () => dialNumber(context, supportPhone),
                ),
              if (!s.branch.demo)
                SubeNavTile(
                  icon: LucideIcons.building2,
                  label: l.agencyInfoTitle,
                  onTap: () => open(const SubeAgencyInfoScreen()),
                ),
              SubeNavTile(
                icon: LucideIcons.bell,
                tint: Dg.violet,
                label: l.subeInboxTitle,
                onTap: () => open(const SubeInboxScreen()),
              ),
            ],
          ),
          SubeOverline(l.profileSettings),
          SubeGroup(
            children: [
              _SwitchRow(
                icon: LucideIcons.moonStar,
                label: l.profileTheme,
                value: s.darkModeUi,
                onChanged: (_) => s.toggleDarkModeUi(),
              ),
              _MotionRow(),
              _LanguageRow(code: s.localeCode, onChanged: s.setLocale),
            ],
          ),
          const SizedBox(height: 24),
          DgButton(
            label: l.subeLogout,
            icon: LucideIcons.logOut,
            tone: DgButtonTone.secondary,
            onPressed: s.logoutAgency,
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                DijigooWordmark(height: 34, onDark: Dg.dark),
                const SizedBox(height: 6),
                Text(
                  '${l.brandTagline} · v$kAppVersion',
                  style: Dg.typeCaption(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Dg.rowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            DgIcon(icon, size: 19, color: Dg.text3),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: Dg.typeLabel())),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Dg.typeBody(weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Dg.rowMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              DgIcon(icon, size: 19, color: Dg.text3),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: Dg.typeBody(weight: FontWeight.w600)),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: Dg.action,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hareket seviyesi: Otomatik (yavaş cihazda kendiliğinden azalır) / Tam /
/// Azaltılmış. Seçim oturum boyunca geçerli.
class _MotionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final governor = MotionGovernor.instance;
    return ListenableBuilder(
      listenable: governor.listenable,
      builder: (context, _) {
        final current = governor.userLevel.value;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DgIcon(LucideIcons.sparkles, size: 19, color: Dg.text3),
                  const SizedBox(width: 14),
                  Text(
                    l.profileMotion,
                    style: Dg.typeBody(weight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<MotionLevel?>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: null, label: Text(l.motionAuto)),
                  ButtonSegment(
                    value: MotionLevel.full,
                    label: Text(l.motionFull),
                  ),
                  ButtonSegment(
                    value: MotionLevel.reduced,
                    label: Text(l.motionReduced),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (v) => governor.userLevel.value = v.first,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.code, required this.onChanged});

  final String code;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          DgIcon(LucideIcons.languages, size: 19, color: Dg.text3),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l.profileLanguage,
              style: Dg.typeBody(weight: FontWeight.w600),
            ),
          ),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'tr', label: Text('TR')),
              ButtonSegment(value: 'en', label: Text('EN')),
            ],
            selected: {code},
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        ],
      ),
    );
  }
}
