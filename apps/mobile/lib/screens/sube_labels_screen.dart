import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../label_pdf.dart';
import '../label_print_sheet.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import '../zpl_printer.dart';
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

  /// Telefonla eşleşmiş Bluetooth cihazlarından yazıcı seçtirir.
  Future<void> _pickBluetooth(BranchWorkspace branch) async {
    final l = context.l10n;
    final List<({String name, String address})> devices;
    try {
      devices = await pairedBluetoothPrinters();
    } catch (_) {
      if (mounted) subeSnack(context, l.btPrinterNone);
      return;
    }
    if (!mounted) return;
    if (devices.isEmpty) {
      subeSnack(context, l.btPrinterNone);
      return;
    }
    final picked = await showModalBottomSheet<({String name, String address})>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(
              l.btPrinterTitle,
              style: Dg.ui(size: 18, weight: FontWeight.w700),
            ),
            for (final d in devices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: DgIcon(LucideIcons.printer, color: Dg.ink2),
                title: Text(d.name.isEmpty ? d.address : d.name),
                onTap: () => Navigator.of(sheet).pop(d),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    branch.setPrinterHost(
      bluetoothPrinterHost(address: picked.address, name: picked.name),
    );
  }

  Future<void> _print(BranchWorkspace branch, List<PrintableLabel> items) async {
    if (kIsWeb) return _printPdf(branch, items);
    // Bluetooth yazıcı seçiliyken boş IP alanı ayarı ezmesin.
    if (!isBluetoothPrinter(branch.printerHost)) {
      branch.setPrinterHost(_printer.text);
    }
    return _guard(() => branch.printLabels(items), context.l10n.labelsPrinted);
  }

  /// Web: etiket PDF'i hazırlanır, ayrı bir "Yazdır" dokunuşuyla telefonun
  /// paylaş/yazdır menüsü açılır; ancak o zaman sunucuda basıldı sayılır.
  Future<void> _printPdf(
    BranchWorkspace branch,
    List<PrintableLabel> items,
  ) async {
    setState(() => _busy = true);
    final pdf = await buildLabelPdfWithAppFont([
      for (final item in items) labelSheetFromPrintable(item),
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!await showLabelPdfSheet(context, pdf, items.length)) return;
    if (!mounted) return;
    await _guard(
      () => branch.printLabels(items, viaPdf: true),
      context.l10n.labelsPrinted,
    );
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
            if (kIsWeb)
              // Tarayıcı Bluetooth'a / ağ yazıcısına erişemez.
              Text(
                l.webPrinterNote,
                style: Dg.ui(size: 13, color: Dg.ink3),
              )
            else if (isBluetoothPrinter(branch.printerHost))
              // Bluetooth yazıcı seçiliyken IP alanı yerine cihaz adı.
              Row(
                children: [
                  DgIcon(LucideIcons.bluetooth, size: 18, color: Dg.ink2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.btPrinterSelected(
                        printerDisplayName(branch.printerHost),
                      ),
                      style: Dg.ui(size: 15, weight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => branch.setPrinterHost(''),
                    child: Text(l.btPrinterRemove),
                  ),
                ],
              )
            else ...[
              TextField(
                controller: _printer,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l.printerAddress,
                  hintText: l.printerHint,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _pickBluetooth(branch),
                  icon: DgIcon(LucideIcons.bluetooth, size: 16, color: Dg.plum),
                  label: Text(l.btPrinterPick),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: type,
              decoration: InputDecoration(labelText: l.labelType),
              items: [
                for (final t in data.labelTypes)
                  DropdownMenuItem(
                    value: t,
                    child: Text(
                      l.labelTypeName(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            if (data.warehouses.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: warehouseId,
                decoration: InputDecoration(labelText: l.pickWarehouse),
                items: [
                  for (final w in data.warehouses)
                    DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        w.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            if (data.recentLabels.isNotEmpty) ...[
              const SizedBox(height: 16),
              SubeSection(l.recentLabels),
              for (final label in data.recentLabels)
                _LabelTile(
                  label: label,
                  onPrint: _busy ? null : () => _print(branch, [label]),
                ),
            ],
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
