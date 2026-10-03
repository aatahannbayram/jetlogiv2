import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';

class _Box {
  _Box(this.ref, this.label, this.status, this.tone);
  final String ref;
  String label;
  String status;
  final String tone;
  final items = <String>['İade evrak', 'Hasarlı ürün'];
}

class SubeDispatchScreen extends StatefulWidget {
  const SubeDispatchScreen({super.key});

  @override
  State<SubeDispatchScreen> createState() => _SubeDispatchScreenState();
}

class _SubeDispatchScreenState extends State<SubeDispatchScreen> {
  final _boxes = [
    _Box('KL-2025-001', 'İade — 38 kayıt', 'Hazır', 'lo'),
    _Box('KL-2025-002', 'Evrak — 15 kayıt', 'Hazır', 'lo'),
    _Box('KL-2025-003', 'Stok — 42 kayıt', 'Taslak', 'mid'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeDispatchTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          DgButton(
            label: l.newPackage,
            icon: LucideIcons.plus,
            onPressed: () => setState(() {
              _boxes.insert(0, _Box('KL-NEW-${_boxes.length}', 'Taslak koli', 'Taslak', 'mid'));
            }),
          ),
          const SizedBox(height: 16),
          for (final box in _boxes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DgCard(
                onTap: () => _open(context, l, box),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Mono(box.ref, size: 13, weight: FontWeight.w700),
                          Text(box.label, style: Dg.ui(size: 14, color: Dg.ink2)),
                        ],
                      ),
                    ),
                    StatusChip(label: box.status, tone: box.tone),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, L10n l, _Box box) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BoxDetail(box: box),
      ),
    );
    setState(() {});
  }
}

class _BoxDetail extends StatefulWidget {
  const _BoxDetail({required this.box});
  final _Box box;

  @override
  State<_BoxDetail> createState() => _BoxDetailState();
}

class _BoxDetailState extends State<_BoxDetail> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final box = widget.box;
    return Scaffold(
      appBar: AppBar(title: Text(box.ref)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final item in box.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DgCard(child: Text(item, style: Dg.ui(size: 14))),
            ),
          DgButton(
            label: l.addUncoded,
            tone: DgButtonTone.secondary,
            onPressed: () => setState(() => box.items.add('Barkodsuz evrak')),
          ),
          const SizedBox(height: 8),
          DgButton(
            label: l.closePackage,
            onPressed: () {
              box.status = 'Hazır';
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          DgButton(
            label: l.dispatchNow,
            icon: LucideIcons.truck,
            tone: DgButtonTone.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
