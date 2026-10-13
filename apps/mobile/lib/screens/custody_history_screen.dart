import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/panel_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Kuryenin aldığı ve verdiği zimmet kalemleri, yeniden eskiye.
class CustodyHistoryScreen extends ConsumerStatefulWidget {
  const CustodyHistoryScreen({super.key});

  @override
  ConsumerState<CustodyHistoryScreen> createState() =>
      _CustodyHistoryScreenState();
}

class _CustodyHistoryScreenState extends ConsumerState<CustodyHistoryScreen> {
  List<CustodyMoveDto>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(sessionProvider).custodyHistory();
      if (mounted) {
        setState(() {
          _items = rows;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static String _when(DateTime? at) {
    if (at == null) return '';
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(l.custodyHistoryTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_failed)
              DgRetryBanner(
                message: l.reportFailedLoad,
                onRetry: _load,
                retryLabel: l.retryNow,
              )
            else if (items == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    l.custodyHistoryEmpty,
                    style: Dg.ui(size: 15, color: Dg.ink2),
                  ),
                ),
              )
            else
              for (final m in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DgCard(
                    child: Row(
                      children: [
                        IconTintBadge(
                          icon: m.incoming
                              ? LucideIcons.arrowDownLeft
                              : LucideIcons.arrowUpRight,
                          tint: m.incoming ? Dg.greenBg : Dg.amberBg,
                          ink: m.incoming ? Dg.green : Dg.amber,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  l.custodyMove(m.incoming),
                                  if (m.shipmentNumber.isNotEmpty)
                                    m.shipmentNumber,
                                ].join(' · '),
                                style: Dg.ui(size: 15, weight: FontWeight.w700),
                              ),
                              if (m.recipientName.isNotEmpty)
                                Text(
                                  m.recipientName,
                                  style: Dg.ui(size: 14, color: Dg.ink2),
                                ),
                              Text(
                                [
                                  m.counterparty,
                                  l.custodyMoveStatus(m.status),
                                  _when(m.at),
                                ].where((e) => e.isNotEmpty).join(' · '),
                                style: Dg.ui(size: 13, color: Dg.ink3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
