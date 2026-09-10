import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final canSeePricing = s.courier.canSeePricing;

    return Scaffold(
      appBar: AppBar(title: Text(l.earnings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (canSeePricing)
            DgCard(
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Mono(l.todayCaps, size: 11, color: Dg.ink3),
                  const SizedBox(height: 8),
                  Text('${s.deliveredCount}', style: Dg.stat(size: 34)),
                  const SizedBox(height: 2),
                  Text(
                    l.packagesDeliveredToday,
                    style: Dg.ui(size: 13, color: Dg.ink2),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      StatTile(
                        label: l.dispatchToday,
                        value: '${s.dispatchCount}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const DgDivider(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        l.todaysEarningsLabel,
                        style: Dg.ui(size: 13, color: Dg.ink3),
                      ),
                      const Spacer(),
                      Text(
                        SessionController.todayEarn,
                        style: Dg.ui(size: 14, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(l.thisWeek, style: Dg.ui(size: 13, color: Dg.ink3)),
                      const Spacer(),
                      Text(
                        SessionController.weekEarn,
                        style: Dg.ui(size: 14, weight: FontWeight.w700),
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
                        ? l.agencyMonthly
                        : l.monthlyFixed,
                    size: 11,
                    color: Dg.ink3,
                  ),
                  const SizedBox(height: 8),
                  Text(s.courier.monthlyPayLabel, style: Dg.stat(size: 34)),
                  const SizedBox(height: 6),
                  Text(
                    s.courier.affiliation == CourierAffiliation.agency
                        ? l.agencyPricingHint
                        : l.fixedMonthlyHint,
                    style: Dg.ui(size: 13, color: Dg.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatTile(label: l.deliveredCaps, value: '${s.deliveredCount}'),
                const SizedBox(width: 12),
                StatTile(label: l.openCaps, value: '${s.openCount}'),
                const SizedBox(width: 12),
                StatTile(label: l.returnCaps, value: '${s.returnCount}'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l.weekly,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 14),
          DgCard(
            child: SizedBox(
              height: 142,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, b) in s.weeklyBars.indexed)
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
                              l.weekdayAt(i),
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
            Text(
              l.bonuses,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
