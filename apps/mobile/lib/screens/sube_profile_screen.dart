import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../api/client.dart' show kAppVersion;
import '../branch_features.dart';
import '../branch_workspace.dart';
import '../launchers.dart';
import '../brand.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_header.dart';
import 'sube_inbox_screen.dart';
import 'sube_partner_screens.dart';
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
    final phone = user?.agency.supportPhone ?? BranchFeatures.supportPhone;
    final support = phone.trim().isEmpty ? null : phone.trim();
    final roles = [
      for (final r in user?.roles ?? const [])
        (l.isEn ? r.nameEn : r.nameTr) ?? r.code,
    ];
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: const SubeHeaderBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          DgPageTitle(l.profileTitle),
          Appear(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: Dg.card(radius: 24),
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
                              DgStatusPill(
                                label: l.profileCanOperate,
                                tone: DgTone.ok,
                                icon: LucideIcons.circleCheck,
                                dense: true,
                              ),
                            if (caps.manage)
                              DgStatusPill(
                                label: l.profileCanManage,
                                tone: DgTone.accent,
                                icon: LucideIcons.shieldCheck,
                                dense: true,
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
              if (!s.branch.demo)
                SubeNavTile(
                  icon: LucideIcons.building2,
                  label: l.agencyInfoTitle,
                  onTap: () => open(const SubeAgencyInfoScreen()),
                ),
              SubeNavTile(
                icon: LucideIcons.fileSignature,
                tint: Dg.violet,
                label: l.profilePartnerDocs,
                onTap: () => open(const SubePartnerDocsScreen()),
              ),
              SubeNavTile(
                icon: LucideIcons.receipt,
                tint: Dg.ok,
                label: l.profileInvoices,
                onTap: () => open(const SubeBillingScreen()),
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
              SubeNavTile(
                icon: LucideIcons.cloudUpload,
                tint: Dg.warn,
                label: l.profileOffline,
                trailing: s.branch.pendingScans > 0
                    ? DgStatusPill(
                        label: '${s.branch.pendingScans}',
                        tone: DgTone.warn,
                        dense: true,
                      )
                    : null,
                onTap: () => open(const SubeOfflineScreen()),
              ),
            ],
          ),
          SubeOverline(l.profileSupport),
          SubeGroup(
            children: [
              SubeNavTile(
                icon: LucideIcons.circleHelp,
                label: l.trainingFaqTitle,
                onTap: () => _faq(context, s.branch),
              ),
              SubeNavTile(
                key: const Key('call-support'),
                icon: LucideIcons.headset,
                tint: Dg.ok,
                label: l.profileCallSupport,
                onTap: support != null
                    ? () => dialNumber(context, support)
                    : () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Dg.surface,
                        showDragHandle: true,
                        builder: (ctx) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: DgPendingBackend(what: l.supportLineWhat),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DgButton(
            key: const Key('sube-logout'),
            label: l.subeLogout,
            icon: LucideIcons.logOut,
            tone: DgButtonTone.danger,
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

/// Sıkça sorulan sorular (Eğitim Merkezi SSS ucu, şube kullanıcısı).
Future<void> _faq(BuildContext context, BranchWorkspace branch) {
  final l = context.l10n;
  final future = branch
      .trainingFaq('BRANCH')
      .catchError((Object _) => const <TrainingFaq>[]);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Dg.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
      ),
      child: FutureBuilder<List<TrainingFaq>>(
        future: future,
        builder: (ctx, snap) {
          final items = snap.data ?? const <TrainingFaq>[];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(l.trainingFaqTitle, style: Dg.typeH2()),
              const SizedBox(height: 8),
              if (snap.connectionState != ConnectionState.done)
                const DgSkeleton(height: 120, radius: 12)
              else if (items.isEmpty)
                Text(l.nothingWaiting, style: Dg.typeCaption())
              else
                for (final f in items)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 10),
                    expandedAlignment: Alignment.centerLeft,
                    shape: const Border(),
                    title: Text(
                      f.question,
                      style: Dg.ui(size: 15, weight: FontWeight.w600),
                    ),
                    children: [Text(f.answer, style: Dg.typeCaption())],
                  ),
            ],
          );
        },
      ),
    ),
  );
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
            Text(label, style: Dg.typeLabel()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
