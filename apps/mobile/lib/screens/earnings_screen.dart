import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final canSeePricing = s.courier.canSeePricing;

    return Scaffold(
      appBar: AppBar(title: const Text('Kazanç & Prim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (canSeePricing)
            DgCard(
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Mono('BUGÜN', size: 11, color: Dg.ink3),
                  const SizedBox(height: 8),
                  Text(SessionController.todayEarn, style: Dg.stat(size: 34)),
                  const SizedBox(height: 6),
                  Text(
                    SessionController.earnDelta,
                    style: Dg.ui(size: 13, color: Dg.purpleDeep),
                  ),
                  const SizedBox(height: 14),
                  const DgDivider(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Bu hafta', style: Dg.ui(size: 14, color: Dg.ink2)),
                      const Spacer(),
                      Text(
                        SessionController.weekEarn,
                        style: Dg.ui(size: 16, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            DgCard(
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Mono(
                    s.courier.affiliation == CourierAffiliation.agency
                        ? 'ACENTA · AYLIK KARŞILIK'
                        : 'AYLIK SABİT',
                    size: 11,
                    color: Dg.ink3,
                  ),
                  const SizedBox(height: 8),
                  Text(s.courier.monthlyPayLabel, style: Dg.stat(size: 34)),
                  const SizedBox(height: 6),
                  Text(
                    s.courier.affiliation == CourierAffiliation.agency
                        ? 'Fiyatlandırma acenta tarafından yönetilir.'
                        : 'Sabit aylık ücretlisiniz, teslimat başına tutar gösterilmez.',
                    style: Dg.ui(size: 13, color: Dg.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatTile(label: 'TESLİM', value: '${s.deliveredCount}'),
                const SizedBox(width: 12),
                StatTile(label: 'AÇIK', value: '${s.openCount}'),
                const SizedBox(width: 12),
                StatTile(label: 'İADE', value: '${s.returnCount}'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Haftalık',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 14),
          DgCard(
            child: SizedBox(
              height: 142,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in s.weeklyBars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Mono(
                              '${(b.value * 100).round()}%',
                              size: 10,
                              color: b.value == 1 ? Dg.purple : Dg.ink3,
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              height: 20 + b.value * 64,
                              decoration: BoxDecoration(
                                color: b.value == 1 ? Dg.purple : Dg.ink,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              b.label,
                              style: Dg.ui(size: 11, color: Dg.ink3),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (canSeePricing) ...[
            const SizedBox(height: 20),
            const Text(
              'Primler',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 10),
          ],
          if (canSeePricing)
            for (final (i, b) in s.bonuses.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StaggerIn(
                  index: i,
                  child: DgCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                b.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Text(b.amount, style: Dg.stat(size: 17)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: b.pct,
                            minHeight: 6,
                            backgroundColor: Dg.elev,
                            valueColor: AlwaysStoppedAnimation(b.color),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(b.meta, style: Dg.ui(size: 12, color: Dg.ink3)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
