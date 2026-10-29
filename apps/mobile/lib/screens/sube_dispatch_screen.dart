import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../motion.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import 'sube_labels_screen.dart';
import 'sube_scan_sheet.dart';
import 'sube_widgets.dart';

/// Merkeze Transfer (mockup 10): tür sekmeleri ve merkez seçilir, gönderi /
/// koli barkodları okutularak taslak toplanır, tek transfer olarak
/// gönderilir. Koli barkodu toplu taşıma anahtarıdır; içindeki her gönderi
/// kendi kimliğini korur. Barkodsuz ekipman / evrak önce iç etiket alır.
class SubeDispatchScreen extends ConsumerStatefulWidget {
  const SubeDispatchScreen({super.key});

  @override
  ConsumerState<SubeDispatchScreen> createState() => _SubeDispatchScreenState();
}

class _SubeDispatchScreenState extends ConsumerState<SubeDispatchScreen> {
  String? _type;
  String? _centerId;
  bool _busy = false;
  int? _sent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadOutgoing();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final options = branch.outgoing;
    final canOperate = branch.capabilities.operate;
    final types = options?.transferTypes ?? const <String>[];
    final type = _type ?? types.firstOrNull;
    final centers = options?.centers ?? const [];
    final centerId = _centerId ?? centers.firstOrNull?.id;
    final center = centers.where((c) => c.id == centerId).firstOrNull;
    final draft = branch.draft;
    return Scaffold(
      appBar: AppBar(title: Text(l.transferOutgoing)),
      body: _sent != null
          ? _Sent(count: _sent!, onAgain: () => setState(() => _sent = null))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                SubeStatusBanner(branch: branch, onRetry: branch.loadOutgoing),
                if (options == null)
                  if (branch.loading)
                    const DgSkeleton(height: 160, radius: 16)
                  else
                    const SizedBox.shrink()
                else ...[
                  if (types.isNotEmpty)
                    DgPillTabs(
                      labels: [for (final t in types) l.transferTypeName(t)],
                      index: types.indexOf(type!).clamp(0, types.length - 1),
                      onChanged: (i) => setState(() => _type = types[i]),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DgFilterChip(
                      label: l.transferCenter,
                      value: center?.name,
                      icon: LucideIcons.building2,
                      onTap: () async {
                        final r = await showDgPicker<String>(
                          context,
                          title: l.transferCenter,
                          allLabel: centers.firstOrNull?.name ?? l.all,
                          options: [
                            for (final c in centers.skip(1)) (c.id, c.name),
                          ],
                          selected: _centerId == centers.firstOrNull?.id
                              ? null
                              : _centerId,
                        );
                        if (r.picked && mounted) {
                          setState(() => _centerId = r.value);
                        }
                      },
                    ),
                  ),
                  if (type != null && type != 'RETURN') ...[
                    const SizedBox(height: 10),
                    DgPanel(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const DgIconBadge(
                            icon: LucideIcons.tag,
                            tone: DgTone.accent,
                            size: 36,
                            soft: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.dispatchLabelHint,
                              style: Dg.typeCaption(),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SubeLabelsScreen(),
                              ),
                            ),
                            child: Text(l.openLabels),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (canOperate) ...[
                    DgGradientButton(
                      label: l.scanAction,
                      icon: LucideIcons.scanLine,
                      onPressed: () => showSubeScanSheet(
                        context,
                        scanContext: ScanContext.dispatch,
                        hint: 'Merkeze gidecek gönderi veya koli barkodunu okutun',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DgPanel(
                      title: l.draftCount(draft.length),
                      child: draft.isEmpty
                          ? Text(l.draftEmpty, style: Dg.typeCaption())
                          : Column(
                              children: [
                                for (var i = 0; i < draft.length; i++)
                                  StaggerIn(
                                    index: i,
                                    child: Row(
                                      children: [
                                        DgIconBadge(
                                          icon: draft[i].isPackage
                                              ? LucideIcons.boxes
                                              : LucideIcons.package,
                                          tone: DgTone.info,
                                          size: 34,
                                          soft: true,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                draft[i].isPackage
                                                    ? draft[i].barcode
                                                    : draft[i].shipmentNumber,
                                                style: Dg.ui(
                                                  size: 15,
                                                  weight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                draft[i].isPackage
                                                    ? l.parcelLabel
                                                    : draft[i].product,
                                                style: Dg.typeCaption(),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: l.cancel,
                                          icon: const Icon(
                                            LucideIcons.x,
                                            size: 18,
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () => branch.removeFromDraft(
                                                  draft[i].barcode,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    DgGradientButton(
                      key: const Key('dispatch-send'),
                      label: '${l.sendTransfer} (${draft.length})',
                      icon: LucideIcons.truck,
                      busy: _busy,
                      onPressed:
                          draft.isEmpty || type == null || centerId == null
                          ? null
                          : () => _send(type, centerId, draft.length),
                    ),
                  ] else
                    Text(l.noPermission, style: Dg.typeCaption()),
                  const SizedBox(height: 16),
                  DgPanel(
                    title: l.recentTransfers,
                    child: options.recent.isEmpty
                        ? Text(l.nothingWaiting, style: Dg.typeCaption())
                        : Column(
                            children: [
                              for (final t in options.recent)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.transferNumber,
                                              style: Dg.ui(
                                                size: 15,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${l.transferTypeName(t.type)} · '
                                              '${t.acceptedItemCount} / '
                                              '${t.itemCount}',
                                              style: Dg.typeCaption(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DgStatusPill(
                                        label: l.transferStatus(t.statusCode),
                                        tone: t.statusCode == 'ACCEPTED'
                                            ? DgTone.ok
                                            : DgTone.warn,
                                        dense: true,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _send(String type, String centerId, int count) async {
    setState(() => _busy = true);
    final error = await ref
        .read(sessionProvider)
        .branch
        .sendDraft(transferType: type, centerId: centerId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) _sent = count;
    });
    if (error != null) subeSnack(context, error);
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.count, required this.onAgain});

  final int count;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DoneRing(icon: LucideIcons.truck),
          const SizedBox(height: 20),
          Text(
            l.dispatchSentTitle,
            textAlign: TextAlign.center,
            style: Dg.ui(size: 20, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(l.draftCount(count), style: Dg.typeCaption()),
          const SizedBox(height: 28),
          DgGradientButton(label: l.newTransfer, onPressed: onAgain),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.done),
          ),
        ],
      ),
    );
  }
}
