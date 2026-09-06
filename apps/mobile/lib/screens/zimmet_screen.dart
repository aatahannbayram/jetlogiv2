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

class _ZimmetScreenState extends ConsumerState<ZimmetScreen> {
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
              child: DgButton(
                label: l.complete,
                icon: LucideIcons.check,
                busy: s.custodyHandoverPending,
                onPressed: s.zimmetScans.isEmpty || s.custodyHandoverPending
                    ? null
                    : () async {
                        final ok = await s.completeZimmet();
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l.handoverFailed),
                            ),
                          );
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
