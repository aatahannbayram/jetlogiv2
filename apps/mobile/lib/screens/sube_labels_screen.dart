import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Koli / paket etiketi üretir ve ağdaki Zebra yazıcıya basar. Barkodu
/// olmayan evrak ya da materyal için sistem iç barkodu da buradan üretilir.
/// Etiketi sunucu çizer (ZPL); uygulama yeniden yorumlamaz.
class SubeLabelsScreen extends ConsumerStatefulWidget {
  const SubeLabelsScreen({super.key});

  @override
  ConsumerState<SubeLabelsScreen> createState() => _SubeLabelsScreenState();
}

class _SubeLabelsScreenState extends ConsumerState<SubeLabelsScreen> {
  final _printer = TextEditingController();
  final _reference = TextEditingController();
  String? _type;
  String? _warehouseId;
  int _quantity = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final branch = ref.read(sessionProvider).branch;
      await branch.loadLabels();
      if (mounted) _printer.text = branch.printerHost;
    });
  }

  @override
  void dispose() {
    _printer.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<String?> Function() run, String done) async {
    setState(() => _busy = true);
    final error = await run();
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? done);
  }

  Future<void> _print(BranchWorkspace branch, List<PrintableLabel> items) {
    branch.setPrinterHost(_printer.text);
    return _guard(() => branch.printLabels(items), context.l10n.labelsPrinted);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final data = branch.labels;
    final canOperate = branch.capabilities.operate;
    final type = _type ?? data?.labelTypes.firstOrNull;
    final warehouseId = _warehouseId ?? data?.warehouses.firstOrNull?.id;
    final fresh = branch.freshLabels;
    return Scaffold(
      appBar: AppBar(title: Text(l.subeLabelsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SubeStatusBanner(branch: branch, onRetry: branch.loadLabels),
          if (data == null)
            if (branch.loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              const SizedBox.shrink()
          else if (!canOperate)
            Text(l.noPermission, style: Dg.ui(size: 13, color: Dg.ink3))
          else ...[
            TextField(
              controller: _printer,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.printerAddress,
                hintText: l.printerHint,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(labelText: l.labelType),
              items: [
                for (final t in data.labelTypes)
                  DropdownMenuItem(value: t, child: Text(l.labelTypeName(t))),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            if (data.warehouses.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: warehouseId,
                decoration: InputDecoration(labelText: l.pickWarehouse),
                items: [
                  for (final w in data.warehouses)
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: (v) => setState(() => _warehouseId = v),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(l.labelQuantity, style: Dg.ui(size: 15))),
                IconButton(
                  icon: const Icon(LucideIcons.minus),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Mono('$_quantity', size: 16, weight: FontWeight.w700),
                IconButton(
                  icon: const Icon(LucideIcons.plus),
                  onPressed: _quantity < 200
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                labelText: l.labelShipmentRef,
                helperText: l.labelShipmentRefHint,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            DgButton(
              label: l.generateLabels,
              icon: LucideIcons.tag,
              busy: _busy,
              onPressed: type == null || warehouseId == null
                  ? null
                  : () => _guard(
                      () => branch.generateLabels(
                        typeCode: type,
                        quantity: _quantity,
                        warehouseId: warehouseId,
                        shipmentReference: _reference.text.trim(),
                      ),
                      l.done,
                    ),
            ),
            if (fresh.isNotEmpty) ...[
              const SizedBox(height: 16),
              SubeSection(l.newLabels, trailing: '${fresh.length}'),
              for (final label in fresh) _LabelTile(label: label),
              DgButton(
                label: l.printLabelsN(fresh.length),
                icon: LucideIcons.printer,
                tone: DgButtonTone.secondary,
                busy: _busy,
                onPressed: () => _print(branch, fresh),
              ),
            ],
            const SizedBox(height: 16),
            SubeSection(l.recentLabels),
            for (final label in data.recentLabels)
              _LabelTile(
                label: label,
                onPrint: _busy ? null : () => _print(branch, [label]),
              ),
          ],
        ],
      ),
    );
  }
}

class _LabelTile extends StatelessWidget {
  const _LabelTile({required this.label, this.onPrint});

  final PrintableLabel label;
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DgCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Mono(label.barcode, size: 13, weight: FontWeight.w700),
                  Text(
                    [
                      l.labelTypeName(label.typeCode),
                      if (label.shipmentNumber.isNotEmpty) label.shipmentNumber,
                      label.printCount == 0
                          ? l.notPrinted
                          : l.printedTimes(label.printCount),
                    ].join(' · '),
                    style: Dg.ui(size: 12, color: Dg.ink3),
                  ),
                ],
              ),
            ),
            if (onPrint != null)
              IconButton(
                tooltip: l.printLabel,
                icon: const Icon(LucideIcons.printer, size: 18),
                onPressed: onPrint,
              ),
          ],
        ),
      ),
    );
  }
}
