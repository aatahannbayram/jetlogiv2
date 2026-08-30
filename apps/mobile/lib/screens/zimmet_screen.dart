import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final barcode = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).setZimmetMode(widget.mode);
    });
  }

  @override
  void dispose() {
    barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final title = s.zimmetMode == 'kurye' ? 'Kurye Zimmet' : 'Şube Zimmet';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SegmentedTabs(
                labels: const ['Kurye', 'Şube'],
                index: s.zimmetMode == 'kurye' ? 0 : 1,
                onChanged: (i) => s.setZimmetMode(i == 0 ? 'kurye' : 'sube'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: DgCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcode,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: s.zimmetScans.isEmpty ? 'Barkodu çerçeveye getir' : 'Son okunan: ${s.zimmetScans.first.code}',
                        ),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        onSubmitted: (v) {
                          s.addZimmetScan(v);
                          barcode.clear();
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        s.addZimmetScan(barcode.text);
                        barcode.clear();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: Dg.purple, shape: BoxShape.circle),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('${s.zimmetScans.length} okundu', style: Dg.ui(size: 14, color: Dg.ink2)),
                  const Spacer(),
                  GestureDetector(
                    onTap: s.toggleBeep,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: s.beepEnabled ? Dg.purple : Dg.elev,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.beepEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            size: 15,
                            color: s.beepEnabled ? Colors.white : Dg.ink,
                          ),
                          const SizedBox(width: 6),
                          Text('Bip', style: Dg.ui(size: 12, weight: FontWeight.w700, color: s.beepEnabled ? Colors.white : Dg.ink)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: s.zimmetScans.isEmpty
                  ? Center(child: Text('Henüz taranan gönderi yok', style: Dg.ui(size: 15, color: Dg.ink3)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      itemCount: s.zimmetScans.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final row = s.zimmetScans[i];
                        return DgCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(child: Mono(row.code, size: 14, weight: FontWeight.w700, color: Dg.ink)),
                              Mono(row.time, size: 12),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton(
                onPressed: s.zimmetScans.isEmpty || s.custodyHandoverPending
                    ? null
                    : () async {
                        final ok = await s.completeZimmet();
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Devir gönderilemedi, tekrar deneyin.')),
                          );
                        }
                      },
                child: s.custodyHandoverPending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Tamamla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
