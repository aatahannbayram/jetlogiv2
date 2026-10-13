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

  static const _monthsTr = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _pct(L10n l, num? v) {
    if (v == null) return '—';
    final n = v.toStringAsFixed(1);
    return l.isEn ? '$n%' : '%${n.replaceAll('.', ',')}';
  }

  /// Sunucunun `2026-01-01` gününü "1 Oca" diye gösterir.
  static String _day(L10n l, String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day} ${(l.isEn ? _monthsEn : _monthsTr)[d.month - 1]}';
  }

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
                (l.perfDeliveryRate, _pct(l, p.deliveryRate)),
                (l.perfFirstAttempt, _pct(l, p.firstAttemptRate)),
                (l.perfSla, _pct(l, p.slaCompliance)),
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
                                '${l.kpiUndelivered} ${c.failed}',
                                style: Dg.ui(size: 12, color: Dg.ink3),
                              ),
                              Text(
                                '${l.perfFirstAttempt} '
                                '${_pct(l, c.firstAttemptRate)}',
                                style: Dg.ui(size: 12, color: Dg.ink3),
                              ),
                            ],
                          ),
                        ),
                        Mono(_pct(l, c.deliveryRate), weight: FontWeight.w700),
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
                        Expanded(child: Mono(_day(l, d.day), size: 13)),
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
