import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../data/vault.dart';
import '../l10n.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';

/// Zimmet uyuşmazlığı formu: tür, kalem ya da okutulan kod, açıklama.
/// Panelde `courier-custody/disputes` ucuna gider; zimmeti veren şube de
/// görür. Okutulup listede olmayan kod "Fazla" türüyle hazır gelir.
Future<void> showCustodyDisputeSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      builder: (_) => const _DisputeSheet(),
    );

class _DisputeSheet extends ConsumerStatefulWidget {
  const _DisputeSheet();

  @override
  ConsumerState<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends ConsumerState<_DisputeSheet> {
  final _code = TextEditingController();
  final _note = TextEditingController();

  /// Ağ hatasından sonra aynı içerikle yeniden denemede aynı anahtar gider
  /// (sunucu aynı kaydı döner); içerik değişince yeni istektir.
  String _key = Vault.newUuid();
  String _type = 'MISSING';
  String? _itemId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    if (s.custodyItems.isEmpty) unawaited(s.loadCustody());
    final listed = {for (final c in s.custodyItems) c.barcode};
    for (final scan in s.zimmetScans) {
      if (!listed.contains(scan.code)) {
        _type = 'EXCESS';
        _code.text = scan.code;
        break;
      }
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  void _change(VoidCallback edit) => setState(() {
    edit();
    _key = Vault.newUuid();
    _error = null;
  });

  bool get _valid =>
      (!CustodyDispute.needsItem(_type) || _itemId != null) &&
      (!CustodyDispute.needsScan(_type) || _code.text.trim().isNotEmpty) &&
      (_type != 'OTHER' || _note.text.trim().isNotEmpty);

  Future<void> _send() async {
    final l = context.l10n;
    final s = ref.read(sessionProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    String? itemId;
    for (final c in s.disputableCustody) {
      if (c.id == _itemId) itemId = c.transferItemId ?? c.id;
    }
    final out = await s.reportCustodyDispute(
      typeCode: _type,
      idempotencyKey: _key,
      transferItemId: CustodyDispute.needsItem(_type) ? itemId : null,
      scanCode: CustodyDispute.needsScan(_type) ? _code.text.trim() : null,
      note: _note.text,
    );
    if (!mounted) return;
    if (out.error != null) {
      setState(() {
        _busy = false;
        _error = out.error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.disputeSent(out.ticket))));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final items = s.disputableCustody;
    final scans = [for (final scan in s.zimmetScans) scan.code];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.disputeTitle,
              style: Dg.ui(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in CustodyDispute.types)
                  DgChoiceSurface(
                    key: Key('dispute-type-$t'),
                    selected: _type == t,
                    onTap: () => _change(() => _type = t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        l.disputeType(t),
                        style: Dg.ui(size: 14, weight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.disputeTypeHint(_type), style: Dg.typeCaption()),
            if (CustodyDispute.needsItem(_type)) ...[
              const SizedBox(height: 14),
              Text(
                l.disputePickItem,
                style: Dg.ui(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (items.isEmpty && s.custodyLoading)
                const DgSkeleton(height: 48, radius: 12)
              else if (items.isEmpty)
                Text(l.disputeNoItems, style: Dg.ui(size: 14, color: Dg.text2))
              else
                for (final c in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: DgChoiceSurface(
                      selected: _itemId == c.id,
                      onTap: () => _change(() => _itemId = c.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Mono(
                                    c.barcode ?? c.id,
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: Dg.ink,
                                  ),
                                  if (c.description.isNotEmpty)
                                    Text(
                                      c.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Dg.typeCaption(),
                                    ),
                                ],
                              ),
                            ),
                            if (_itemId == c.id)
                              Icon(
                                LucideIcons.check,
                                size: 18,
                                color: Dg.action,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
            if (CustodyDispute.needsScan(_type)) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('dispute-code'),
                controller: _code,
                onChanged: (_) => _change(() {}),
                decoration: InputDecoration(
                  hintText: l.disputeScanCode,
                  prefixIcon: const Icon(LucideIcons.scanLine, size: 18),
                ),
              ),
              if (scans.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final code in scans.take(6))
                      ActionChip(
                        label: Text(code),
                        onPressed: () => _change(() => _code.text = code),
                      ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 10),
            TextField(
              key: const Key('dispute-note'),
              controller: _note,
              onChanged: (_) => _change(() {}),
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: _type == 'OTHER'
                    ? l.disputeNote
                    : l.disputeNoteOptional,
              ),
            ),
            if (_error != null) ...[
              Text(_error!, style: Dg.ui(size: 14, color: Dg.bad)),
              const SizedBox(height: 8),
            ],
            DgButton(
              key: const Key('dispute-send'),
              label: l.disputeSend,
              icon: LucideIcons.send,
              busy: _busy,
              onPressed: _busy || !_valid ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uyuşmazlık kaydı satırı (kurye "bildirimlerim", şube Stok & Zimmet).
class CustodyDisputeTile extends StatelessWidget {
  const CustodyDisputeTile({super.key, required this.dispute});

  final CustodyDispute dispute;

  static IconData _icon(String type) => switch (type) {
    'MISSING' => LucideIcons.packageMinus,
    'EXCESS' => LucideIcons.packagePlus,
    'DAMAGED' => LucideIcons.packageX,
    'WRONG_ITEM' => LucideIcons.replace,
    _ => LucideIcons.circleHelp,
  };

  static String _when(DateTime? at) {
    if (at == null) return '';
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = dispute;
    final subject = d.shipmentNumber ?? d.scanCode ?? d.transferNumber;
    return DgPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DgIconBadge(
            icon: _icon(d.typeCode),
            tone: d.resolved ? DgTone.ok : DgTone.warn,
            size: 40,
            soft: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [l.disputeType(d.typeCode), ?subject].join(' · '),
                  style: Dg.ui(size: 15, weight: FontWeight.w700),
                ),
                Text(
                  [
                    ?d.courierName,
                    ?d.ticketNumber,
                    _when(d.createdAt),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: Dg.typeCaption(),
                ),
                if (d.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      d.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Dg.ui(size: 14, color: Dg.text2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DgStatusPill(
            label: l.disputeStatus(d.statusCode),
            tone: d.resolved ? DgTone.ok : DgTone.info,
            dense: true,
          ),
        ],
      ),
    );
  }
}
