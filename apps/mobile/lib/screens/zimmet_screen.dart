import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../scan.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class ZimmetScreen extends ConsumerStatefulWidget {
  const ZimmetScreen({super.key, required this.mode});

  final String mode;

  @override
  ConsumerState<ZimmetScreen> createState() => _ZimmetScreenState();
}

/// Şube zimmeti tamamlandığında gösterilen onay ekranı — kuryenin bunu
/// kapatıp kendi görev akışına açıkça "geri dönmesini" sağlar (toplantı
/// maddesi 14: "Şube girişinden sonra Kurye Geri Dönüş özelliği").
Future<void> _showBranchHandoverDone(BuildContext context, int count) {
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Dg.surface,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Dg.loBg,
                shape: BoxShape.circle,
              ),
              child: DgIcon(LucideIcons.checkCheck, color: Dg.ok, size: 30, weight: 600),
            ),
            const SizedBox(height: 18),
            Text(
              l.branchHandoverDoneTitle,
              style: Dg.ui(size: 17, weight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              l.branchHandoverDoneBody(count),
              style: Dg.ui(size: 14, color: Dg.ink2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            DgButton(
              label: l.returnToCourierWork,
              icon: LucideIcons.arrowLeft,
              tone: DgButtonTone.brand,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ZimmetScreenState extends ConsumerState<ZimmetScreen> {
  Future<void> _finish(
    BuildContext context,
    SessionController s,
    L10n l,
  ) async {
    final handedOver = s.zimmetScans.length;
    final mode = s.zimmetMode;
    final ok = await s.completeZimmet();
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.handoverFailed)),
      );
      return;
    }
    if (mode == 'sube') {
      await _showBranchHandoverDone(context, handedOver);
      if (!context.mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showDiscrepancy(
    BuildContext context,
    SessionController s,
    L10n l,
  ) async {
    final note = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Dg.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.discrepancy, style: Dg.ui(size: 17, weight: FontWeight.w700)),
            TextField(
              controller: note,
              decoration: InputDecoration(hintText: l.discrepancyNote),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            DgButton(
              label: l.discrepancySave,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (saved == true && context.mounted) {
      await _finish(context, s, l);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).setZimmetMode(widget.mode);
    });
  }

  Future<void> _onCode(String code) async {
    final s = ref.read(sessionProvider);
    final before = s.zimmetScans.length;
    s.addZimmetScan(code);
    if (s.zimmetScans.length == before) return;
    await playScanFeedback(beep: s.beepEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final title = s.zimmetMode == 'kurye' ? l.courierCustody : l.branchCustody;
    final known = {for (final row in s.zimmetScans) row.code};

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SegmentedTabs(
                labels: [l.courier, l.branch],
                index: s.zimmetMode == 'kurye' ? 0 : 1,
                onChanged: (i) => s.setZimmetMode(i == 0 ? 'kurye' : 'sube'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: BarcodeScanPane(onDetect: _onCode, known: known),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    l.readCount(s.zimmetScans.length),
                    style: Dg.ui(size: 14, color: Dg.ink2),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: s.toggleBeep,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: s.beepEnabled ? Dg.purple : Dg.elev,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.beepEnabled
                                ? LucideIcons.volume2
                                : LucideIcons.volumeX,
                            size: 15,
                            color: s.beepEnabled ? Colors.white : Dg.ink,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.beep,
                            style: Dg.ui(
                              size: 12,
                              weight: FontWeight.w700,
                              color: s.beepEnabled ? Colors.white : Dg.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: s.zimmetScans.isEmpty
                  ? Center(
                      child: Text(
                        l.noScansYet,
                        style: Dg.ui(size: 15, color: Dg.ink3),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      itemCount: s.zimmetScans.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final row = s.zimmetScans[i];
                        return DgCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Mono(
                                  row.code,
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: Dg.ink,
                                ),
                              ),
                              Mono(row.time, size: 12),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => s.removeZimmetScan(row.code),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: Dg.ink3,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  DgButton(
                    label: l.acceptCustody,
                    icon: LucideIcons.check,
                    busy: s.custodyHandoverPending,
                    onPressed: s.zimmetScans.isEmpty || s.custodyHandoverPending
                        ? null
                        : () => _finish(context, s, l),
                  ),
                  const SizedBox(height: 8),
                  DgButton(
                    label: l.discrepancy,
                    icon: LucideIcons.circleAlert,
                    tone: DgButtonTone.secondary,
                    onPressed: s.zimmetScans.isEmpty
                        ? null
                        : () => _showDiscrepancy(context, s, l),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
