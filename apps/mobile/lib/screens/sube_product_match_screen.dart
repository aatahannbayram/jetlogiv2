import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/branch_models.dart';
import '../l10n.dart';
import '../scan.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Toplu ürün eşleştirme (docs/15 §11): seçili her gönderiye ürünün seri
/// numarası / barkodu bağlanır. Okutulan kod sıradaki boş satıra yazılır;
/// elle de düzeltilebilir. Sunucu teyidi gelmeden "eşleşti" gösterilmez.
class SubeProductMatchScreen extends ConsumerStatefulWidget {
  const SubeProductMatchScreen({super.key, required this.rows});

  final List<BranchShipmentRow> rows;

  @override
  ConsumerState<SubeProductMatchScreen> createState() =>
      _SubeProductMatchScreenState();
}

class _SubeProductMatchScreenState
    extends ConsumerState<SubeProductMatchScreen> {
  late final _fields = {
    for (final r in widget.rows) r.shipmentId: TextEditingController(),
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onCode(String code) {
    final next = _fields.values.where((c) => c.text.trim().isEmpty).firstOrNull;
    if (next == null) return;
    // Aynı ürün iki gönderiye yazılmaz.
    if (_fields.values.any((c) => c.text.trim() == code)) return;
    setState(() => next.text = code);
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final branch = ref.read(sessionProvider).branch;
    final error = await branch.matchProducts({
      for (final e in _fields.entries) e.key: e.value.text,
    });
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    final result = branch.lastProductMatch;
    final failed = result?.failed.length ?? 0;
    subeSnack(
      context,
      failed == 0
          ? l.productMatched(result?.matched ?? 0)
          : l.productMatchPartial(result?.matched ?? 0, failed),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.productMatchTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(l.productMatchHint, style: Dg.typeCaption()),
          const SizedBox(height: 12),
          BarcodeScanPane(onDetect: _onCode),
          const SizedBox(height: 12),
          DgPanel(
            child: Column(
              children: [
                for (final r in widget.rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.shipmentNumber,
                                style: Dg.ui(size: 15, weight: FontWeight.w700),
                              ),
                              Text(
                                r.recipientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Dg.typeCaption(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 5,
                          child: TextField(
                            key: Key('match-${r.shipmentId}'),
                            controller: _fields[r.shipmentId],
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: l.productBarcodeHint,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Dg.hi,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 16),
          DgButton(
            key: const Key('match-save'),
            label: l.productMatchSave,
            busy: _busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
