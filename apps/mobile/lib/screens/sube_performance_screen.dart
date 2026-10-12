import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Şube ve kurye teslim performansı: bugün / 7 gün / 30 gün.
class SubePerformanceScreen extends ConsumerStatefulWidget {
  const SubePerformanceScreen({super.key});

  @override
  ConsumerState<SubePerformanceScreen> createState() =>
      _SubePerformanceScreenState();
}

class _SubePerformanceScreenState extends ConsumerState<SubePerformanceScreen> {
  static const _ranges = ['today', '7d', '30d'];
  int _range = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      ref.read(sessionProvider).branch.loadPerformance(_ranges[_range]);

  static String _pct(num? v) => v == null ? '—' : '%${v.toStringAsFixed(1)}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final loaded = branch.performance;
    final p = loaded?.range == _ranges[_range] ? loaded : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.subePerformanceTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SegmentedTabs(
              labels: [l.rangeToday, l.range7d, l.range30d],
              index: _range,
              onChanged: (i) {
                setState(() => _range = i);
                _load();
              },
            ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch, onRetry: _load),
            if (p == null)
              if (branch.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                const SizedBox.shrink()
            else ...[
              if (p.truncated)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l.perfTruncated,
                    style: Dg.ui(size: 13, color: Dg.mid),
                  ),
                ),
              SubeKpiGrid([
                (l.perfDeliveryRate, _pct(p.deliveryRate)),
                (l.perfFirstAttempt, _pct(p.firstAttemptRate)),
                (l.perfSla, _pct(p.slaCompliance)),
                (
                  l.perfAvgMinutes,
                  p.averageDeliveryMinutes == null
                      ? '—'
                      : '${p.averageDeliveryMinutes!.round()}',
                ),
                (l.perfAttempted, '${p.attemptedShipments}'),
                (l.kpiDelivered, '${p.deliveredShipments}'),
                (l.perfFailed, '${p.failedAttempts}'),
                (l.kpiActiveCouriers, '${p.activeCouriers}'),
              ]),
              SubeSection(l.perfByCourier, trailing: '${p.couriers.length}'),
              for (final c in p.couriers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DgCard(
                    child: Row(
                      children: [
                        InitialsAvatar(name: c.name, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: Dg.ui(size: 15, weight: FontWeight.w600),
                              ),
                              Text(
                                '${l.kpiDelivered} ${c.delivered} · '
                                '${l.kpiUndelivered} ${c.failed} · '
                                '${l.perfFirstAttempt} ${_pct(c.firstAttemptRate)}',
                                style: Dg.ui(size: 12, color: Dg.ink3),
                              ),
                            ],
                          ),
                        ),
                        Mono(_pct(c.deliveryRate), weight: FontWeight.w700),
                      ],
                    ),
                  ),
                ),
              if (p.daily.isNotEmpty) ...[
                SubeSection(l.perfDaily),
                for (final d in p.daily)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Mono(d.day, size: 13)),
                        Text(
                          '${l.kpiDelivered} ${d.delivered} · '
                          '${l.kpiUndelivered} ${d.failed}',
                          style: Dg.ui(size: 13, color: Dg.ink2),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
