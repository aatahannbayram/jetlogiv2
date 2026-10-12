import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../scan_router.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_scan_sheet.dart';
import 'sube_widgets.dart';

/// Merkeze sevk: tür ve merkez seçilir, gönderi / koli barkodları okutularak
/// taslak toplanır, tek transfer olarak gönderilir. Koli barkodu toplu
/// taşıma anahtarıdır; içindeki her gönderi kendi kimliğini korur.
class SubeDispatchScreen extends ConsumerStatefulWidget {
  const SubeDispatchScreen({super.key});

  @override
  ConsumerState<SubeDispatchScreen> createState() => _SubeDispatchScreenState();
}

class _SubeDispatchScreenState extends ConsumerState<SubeDispatchScreen> {
  String? _type;
  String? _centerId;
  bool _busy = false;

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
    final type = _type ?? options?.transferTypes.firstOrNull;
    final centerId = _centerId ?? options?.centers.firstOrNull?.id;
    final draft = branch.draft;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeDispatchTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubeStatusBanner(branch: branch, onRetry: branch.loadOutgoing),
          if (options == null)
            if (branch.loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              const SizedBox.shrink()
          else ...[
            if (canOperate) ...[
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: InputDecoration(labelText: l.transferTypeLabel),
                items: [
                  for (final t in options.transferTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Text(l.transferTypeName(t)),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: centerId,
                decoration: InputDecoration(labelText: l.transferCenter),
                items: [
                  for (final c in options.centers)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _centerId = v),
              ),
              const SizedBox(height: 16),
              DgButton(
                label: l.scanAction,
                icon: LucideIcons.qrCode,
                tone: DgButtonTone.secondary,
                onPressed: () => showSubeScanSheet(
                  context,
                  scanContext: ScanContext.dispatch,
                  hint: 'Merkeze gidecek gönderi veya koli barkodunu okutun',
                ),
              ),
              const SizedBox(height: 12),
              if (draft.isEmpty)
                Text(l.draftEmpty, style: Dg.ui(size: 13, color: Dg.ink3)),
              for (final c in draft)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DgCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Mono(
                                c.isPackage ? c.barcode : c.shipmentNumber,
                                size: 13,
                                weight: FontWeight.w700,
                              ),
                              Text(
                                c.isPackage ? l.parcelLabel : c.product,
                                style: Dg.ui(size: 12, color: Dg.ink3),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: _busy
                              ? null
                              : () => branch.removeFromDraft(c.barcode),
                        ),
                      ],
                    ),
                  ),
                ),
              if (draft.isNotEmpty) ...[
                const SizedBox(height: 8),
                DgButton(
                  label: '${l.sendTransfer} · ${draft.length}',
                  icon: LucideIcons.truck,
                  busy: _busy,
                  onPressed: type == null || centerId == null
                      ? null
                      : () => _send(type, centerId),
                ),
              ],
            ] else
              Text(l.noPermission, style: Dg.ui(size: 13, color: Dg.ink3)),
            const SizedBox(height: 16),
            SubeSection(l.recentTransfers),
            for (final t in options.recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DgCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Mono(
                              t.transferNumber,
                              size: 13,
                              weight: FontWeight.w700,
                            ),
                            Text(
                              '${l.transferTypeName(t.type)} · '
                              '${t.acceptedItemCount} / ${t.itemCount}',
                              style: Dg.ui(size: 13, color: Dg.ink2),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: l.transferStatus(t.statusCode),
                        tone: t.statusCode == 'ACCEPTED' ? 'lo' : 'mid',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _send(String type, String centerId) async {
    final l = context.l10n;
    setState(() => _busy = true);
    final error = await ref
        .read(sessionProvider)
        .branch
        .sendDraft(transferType: type, centerId: centerId);
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? l.transferSent);
  }
}
