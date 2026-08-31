import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  late final doc = TextEditingController(
    text: ref.read(sessionProvider).mrzDoc,
  );
  late final dob = TextEditingController(
    text: ref.read(sessionProvider).mrzDob,
  );

  @override
  void dispose() {
    doc.dispose();
    dob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Test (KYC)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'Doğrulanacak belge türünü seç.',
            style: Dg.ui(size: 15, color: Dg.ink2),
          ),
          const SizedBox(height: 14),
          for (final d in s.kycDocs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DgCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    IconTintBadge(icon: d.icon, tint: Dg.blueBg, ink: Dg.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: Dg.ink3),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          DgCard(
            child: Row(
              children: [
                IconTintBadge(
                  icon: s.nfcRead ? LucideIcons.circleCheck : LucideIcons.nfc,
                  tint: s.nfcRead ? Dg.greenBg : Dg.blueBg,
                  ink: s.nfcRead ? Dg.green : Dg.blue,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nfcRead ? 'Çip okundu' : 'NFC hazır',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.nfcRead
                            ? 'MRZ ile şifre çözüldü · doğrulandı'
                            : 'Kimliği telefonun arkasına yaklaştır',
                        style: Dg.ui(size: 13, color: Dg.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DgCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Mono('BELGE NO', size: 11, color: Dg.ink3),
                const SizedBox(height: 4),
                TextField(
                  controller: doc,
                  onChanged: s.setMrzDoc,
                  style: const TextStyle(
                    fontFamily: Dg.mono,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Mono('DOĞUM TARİHİ (YYMMDD)', size: 11, color: Dg.ink3),
                const SizedBox(height: 4),
                TextField(
                  controller: dob,
                  onChanged: s.setMrzDob,
                  style: const TextStyle(
                    fontFamily: Dg.mono,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: s.nfcRead
                ? FilledButton.styleFrom(
                    backgroundColor: Dg.purple,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: s.nfcRead ? null : s.readNfc,
            child: Text(s.nfcRead ? 'Doğrulandı' : 'NFC ile oku'),
          ),
        ],
      ),
    );
  }
}
