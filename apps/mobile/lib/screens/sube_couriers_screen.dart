import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_demo.dart';

class SubeCouriersScreen extends StatelessWidget {
  const SubeCouriersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeCouriersTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final courier in kSubeDemoCouriers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _CourierDetail(courier: courier),
                  ),
                ),
                child: Row(
                  children: [
                    InitialsAvatar(name: courier.name, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(courier.name, style: Dg.ui(size: 15, weight: FontWeight.w600)),
                          Text(
                            '${courier.onMe} / ${courier.left}',
                            style: Dg.ui(size: 12, color: Dg.ink3),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(label: l.availableStatus, tone: courier.tone),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CourierDetail extends StatefulWidget {
  const _CourierDetail({required this.courier});
  final SubeDemoCourier courier;

  @override
  State<_CourierDetail> createState() => _CourierDetailState();
}

class _CourierDetailState extends State<_CourierDetail> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = [l.perfInstant, l.perfDay, l.perfMonth];
    return Scaffold(
      appBar: AppBar(title: Text(widget.courier.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          StatusChip(label: l.availableStatus, tone: 'lime'),
          const SizedBox(height: 12),
          SegmentedTabs(
            labels: tabs,
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StatTile(label: l.kpiOnMe, value: '${widget.courier.onMe}'),
              const SizedBox(width: 12),
              StatTile(label: l.kpiLeft, value: '${widget.courier.left}'),
            ],
          ),
          const SizedBox(height: 20),
          DgButton(
            label: l.reassign,
            icon: LucideIcons.repeat,
            onPressed: () => _reassign(context, l),
          ),
        ],
      ),
    );
  }

  Future<void> _reassign(BuildContext context, L10n l) async {
    final reason = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Dg.surface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reassign, style: Dg.ui(size: 17, weight: FontWeight.w700)),
            TextField(controller: reason, decoration: InputDecoration(hintText: l.reason)),
            const SizedBox(height: 12),
            DgButton(
              label: l.confirmAssign,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
  }
}
