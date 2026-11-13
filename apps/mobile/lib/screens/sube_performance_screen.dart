import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Şube ve kurye teslim performansı: bugün / 7 gün / 30 gün / özel aralık.
class SubePerformanceScreen extends ConsumerStatefulWidget {
  const SubePerformanceScreen({super.key});

  @override
  ConsumerState<SubePerformanceScreen> createState() =>
      _SubePerformanceScreenState();
}

class _SubePerformanceScreenState extends ConsumerState<SubePerformanceScreen> {
  static const _ranges = ['today', '7d', '30d', 'custom'];
  int _range = 1;
  late String _from;
  late String _to;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    final today = istanbulYmd();
    final start = istanbulClock().subtract(const Duration(days: 6));
    _to = today;
    _from = ymdOf(start);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _key => _range == 3 ? 'custom:$_from:$_to' : _ranges[_range];

  Future<void> _load() async {
    final branch = ref.read(sessionProvider).branch;
    if (_range == 3) {
      final issue = checkCustomRange(_from, _to);
      if (issue != CustomRangeIssue.none) {
        final l = context.l10n;
        setState(() {
          _rangeError = switch (issue) {
            CustomRangeIssue.tooLong => l.rangeTooLong,
            CustomRangeIssue.future => l.rangeFuture,
            CustomRangeIssue.order ||
            CustomRangeIssue.invalid ||
            CustomRangeIssue.none => l.rangeInvalid,
          };
        });
        return;
      }
    }
    setState(() => _rangeError = null);
    await branch.loadPerformance(
      _ranges[_range],
      from: _range == 3 ? _from : null,
      to: _range == 3 ? _to : null,
    );
  }

  Future<void> _pickBound({required bool from}) async {
    final clock = istanbulClock();
    final today = DateTime(clock.year, clock.month, clock.day);
    final current = DateTime.tryParse(from ? _from : _to) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : current,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      final ymd = ymdOf(picked);
      if (from) {
        _from = ymd;
      } else {
        _to = ymd;
      }
    });
    await _load();
  }

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
    final p = loaded?.selectionKey == _key ? loaded : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.subePerformanceTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SegmentedTabs(
              labels: [l.rangeToday, l.range7d, l.range30d, l.rangeCustom],
              index: _range,
              onChanged: (i) {
                setState(() => _range = i);
                _load();
              },
            ),
            if (_range == 3) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickBound(from: true),
                      child: Text('${l.rangeFrom} · ${_day(l, _from)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickBound(from: false),
                      child: Text('${l.rangeTo} · ${_day(l, _to)}'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (_rangeError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_rangeError!, style: Dg.ui(size: 13, color: Dg.hi)),
              ),
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
