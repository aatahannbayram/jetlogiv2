import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_assign_flow.dart';
import 'sube_print.dart';
import 'sube_widgets.dart';

String _stamp(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

/// Gönderi numarası; liste ile detay arasında yerinde uçar (Hero).
class ShipmentNumberHero extends StatelessWidget {
  const ShipmentNumberHero({super.key, required this.row, required this.style});

  final BranchShipmentRow row;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'ship-${row.shipmentId}',
      child: Material(
        type: MaterialType.transparency,
        child: Text(
          row.shipmentNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

/// Kabul bekleyen zimmetin iptal nedeni. Vazgeçilirse null.
Future<ReasonOption?> pickCancelReason(
  BuildContext context,
  BranchWorkspace branch,
) {
  final l = context.l10n;
  final future = branch.cancelReasons();
  return showModalBottomSheet<ReasonOption>(
    context: context,
    backgroundColor: Dg.surface,
    builder: (ctx) => FutureBuilder(
      future: future,
      builder: (ctx, snap) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        shrinkWrap: true,
        children: [
          Text(l.pickReason, style: Dg.ui(size: 17, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (snap.connectionState != ConnectionState.done)
            const Center(child: CircularProgressIndicator())
          else if (snap.hasError)
            Text(
              BranchWorkspace.describeError(snap.error!),
              style: Dg.ui(size: 14, color: Dg.bad),
            ),
          for (final r in snap.data ?? const <ReasonOption>[])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.name),
              onTap: () => Navigator.pop(ctx, r),
            ),
        ],
      ),
    ),
  );
}

/// Gönderi Detayı (mockup 3): üst kart (no, durum, alıcı, adres), aksiyon
/// ızgarası, alıcı / ürün / randevu / müşteri-SLA bölümleri, kurye
/// önerileri ve işlem geçmişi. Listeden gelen satır hemen gösterilir,
/// sunucu detayı gelince dolar.
class SubeShipmentDetailScreen extends ConsumerStatefulWidget {
  const SubeShipmentDetailScreen({super.key, required this.row});

  final BranchShipmentRow row;

  @override
  ConsumerState<SubeShipmentDetailScreen> createState() =>
      _SubeShipmentDetailScreenState();
}

class _SubeShipmentDetailScreenState
    extends ConsumerState<SubeShipmentDetailScreen> {
  late Future<ShipmentDetail?> _detail;
  late Future<Map<String, dynamic>?> _label;
  bool _busy = false;

  BranchWorkspace get _branch => ref.read(sessionProvider).branch;
  String get _id => widget.row.shipmentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _detail = _branch.shipmentDetail(_id);
    // Müşteri, sipariş / referans no ve SLA durumu etiket satırında gelir.
    _label = _branch
        .printRows([_id])
        .then<Map<String, dynamic>?>((rows) => rows.firstOrNull)
        .catchError((Object _) => null);
  }

  void _reload() => setState(_load);

  Future<void> _assign(AssignMode mode, BranchShipmentRow row) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubeAssignFlow(mode: mode, rows: [row]),
      ),
    );
    if (done == true && mounted) _reload();
  }

  Future<void> _cancel(BranchShipmentRow row) async {
    final l = context.l10n;
    final reason = await pickCancelReason(context, _branch);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final error = await _branch.cancelHandover(row, reason.code);
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? l.handoverCancelled);
    if (error == null) _reload();
  }

  Future<void> _print() async {
    setState(() => _busy = true);
    await printShipmentLabels(context, _branch, [_id]);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final latest = branch.rows.where((r) => r.shipmentId == _id).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l.shipmentDetailTitle)),
      body: FutureBuilder<ShipmentDetail?>(
        future: _detail,
        builder: (context, snap) {
          final detail = snap.data;
          final row = detail?.row ?? latest ?? widget.row;
          final loading = snap.connectionState != ConnectionState.done;
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _detail;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _HeaderCard(row: row),
                const SizedBox(height: 12),
                _actions(context, branch, row),
                if (_busy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 16),
                if (snap.hasError)
                  _Notice(
                    text: BranchWorkspace.describeError(snap.error!),
                    onRetry: _reload,
                  )
                else if (!loading && detail == null)
                  _Notice(text: l.shipmentNotHere),
                _section(
                  l.secRecipient,
                  Column(
                    children: [
                      DgInfoRow(
                        icon: LucideIcons.user,
                        label: l.fieldName,
                        value: row.recipientName,
                      ),
                      DgInfoRow(
                        icon: LucideIcons.mapPin,
                        label: l.fieldAddress,
                        value: _address(row),
                      ),
                      DgInfoRow(
                        icon: LucideIcons.phone,
                        label: l.fieldPhone,
                        value: l.phoneHidden,
                      ),
                    ],
                  ),
                ),
                _section(
                  l.secProduct,
                  loading
                      ? const DgSkeleton(height: 88, radius: 12)
                      : Column(
                          children: [
                            DgInfoRow(
                              icon: LucideIcons.package,
                              label: l.fieldProduct,
                              value: row.product,
                            ),
                            if (row.productCode.isNotEmpty)
                              DgInfoRow(
                                icon: LucideIcons.barcode,
                                label: l.fieldProductCode,
                                value: row.productCode,
                              ),
                            DgInfoRow(
                              icon: LucideIcons.boxes,
                              label: l.fieldPackages,
                              value: row.packageCount > 0
                                  ? '${row.packageCount}'
                                  : '',
                            ),
                            if (detail?.weightKg != null)
                              DgInfoRow(
                                icon: LucideIcons.weight,
                                label: l.fieldWeight,
                                value: '${detail!.weightKg} kg',
                              ),
                            if (detail?.packageType != null)
                              DgInfoRow(
                                icon: LucideIcons.box,
                                label: l.fieldPackageType,
                                value: detail!.packageType!,
                              ),
                            if (row.maxDispatches != null)
                              DgInfoRow(
                                icon: LucideIcons.repeat,
                                label: l.fieldAttempts,
                                value:
                                    '${row.dispatches} / ${row.maxDispatches}',
                              ),
                            if (row.courierName.isNotEmpty)
                              DgInfoRow(
                                icon: LucideIcons.bike,
                                label: l.fieldCourier,
                                value: row.courierName,
                              ),
                          ],
                        ),
                ),
                _section(
                  l.secAppointment,
                  Column(
                    children: [
                      DgInfoRow(
                        icon: LucideIcons.calendarClock,
                        label: l.fieldWindow,
                        value: row.windowStart == null
                            ? l.noAppointment
                            : [
                                _stamp(row.windowStart!),
                                if (row.windowEnd != null)
                                  subeClock(row.windowEnd!),
                              ].join(' – '),
                      ),
                      if (row.plannedDeliveryAt != null)
                        DgInfoRow(
                          icon: LucideIcons.calendarCheck,
                          label: l.fieldPlanned,
                          value: _stamp(row.plannedDeliveryAt!),
                        ),
                    ],
                  ),
                ),
                _section(
                  l.secCustomer,
                  _CustomerBlock(row: row, label: _label),
                ),
                if (detail != null &&
                    (detail.canAssign || detail.canChange) &&
                    detail.suggestions.isNotEmpty)
                  _section(
                    l.secSuggestions,
                    Column(
                      children: [
                        for (final s in detail.suggestions.take(3))
                          _SuggestionRow(suggestion: s),
                      ],
                    ),
                  ),
                _section(
                  l.secHistory,
                  loading
                      ? const DgSkeleton(height: 96, radius: 12)
                      : (detail?.recent ?? const []).isEmpty
                      ? Text(l.historyEmpty, style: Dg.typeCaption())
                      : DgTimeline(
                          entries: [
                            for (final e in detail!.recent)
                              () {
                                final view = shipmentEventView(l, e);
                                return (
                                  title: view.title,
                                  subtitle: [
                                    if (e.at != null) _stamp(e.at!),
                                    if (e.actor != null) e.actor!,
                                  ].join(' · '),
                                  tone: view.tone,
                                );
                              }(),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _address(BranchShipmentRow row) => [
    row.addressLine,
    [
      row.neighborhood,
      row.district,
      row.city,
    ].where((e) => e.isNotEmpty).join(' / '),
  ].where((e) => e.isNotEmpty).join('\n');

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DgPanel(title: title, child: child),
  );

  Widget _actions(
    BuildContext context,
    BranchWorkspace branch,
    BranchShipmentRow row,
  ) {
    final l = context.l10n;
    final can = branch.capabilities.operate && !_busy;
    final courierPhone = _courierPhone(branch, row);
    return DgActionGrid(
      items: [
        if (row.stage == BranchStage.awaitingCourier)
          (
            icon: LucideIcons.userPlus,
            label: l.bulkAssign,
            tone: DgTone.info,
            onTap: can ? () => _assign(AssignMode.assign, row) : null,
          ),
        if (row.stage == BranchStage.inQueue ||
            row.stage == BranchStage.inDistribution)
          (
            icon: LucideIcons.repeat,
            label: l.bulkChange,
            tone: DgTone.accent,
            onTap: can
                ? () => _assign(
                    row.stage == BranchStage.inQueue
                        ? AssignMode.change
                        : AssignMode.reassign,
                    row,
                  )
                : null,
          ),
        if (row.stage == BranchStage.inQueue)
          (
            icon: LucideIcons.circleX,
            label: l.cancelHandover,
            tone: DgTone.bad,
            onTap: can ? () => _cancel(row) : null,
          ),
        (
          icon: LucideIcons.printer,
          label: l.printLabel,
          tone: DgTone.neutral,
          onTap: can && row.stage != BranchStage.incoming ? _print : null,
        ),
        (
          icon: LucideIcons.phone,
          label: l.call,
          tone: DgTone.ok,
          onTap: courierPhone == null
              ? null
              : () => dialNumber(context, courierPhone),
        ),
      ],
    );
  }

  /// Gönderideki kuryenin telefonu (canlı kurye listesinden).
  String? _courierPhone(BranchWorkspace branch, BranchShipmentRow row) {
    final couriers = branch.dashboard?.courierList ?? const [];
    final id = row.courier?.id;
    final name = row.courierName;
    if (id == null && name.isEmpty) return null;
    return couriers
        .where((c) => id != null ? c.id == id : c.name == name)
        .firstOrNull
        ?.phone;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.row});

  final BranchShipmentRow row;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DgPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ShipmentNumberHero(
                  row: row,
                  style: Dg.ui(size: 20, weight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              DgStatusPill.of(shipmentStatus(l, row)),
            ],
          ),
          if (row.late || row.highPriority) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                if (row.late)
                  DgStatusPill(
                    label: l.filterLate,
                    tone: DgTone.bad,
                    icon: LucideIcons.clockAlert,
                    dense: true,
                  ),
                if (row.highPriority)
                  DgStatusPill(
                    label: l.filterPriority,
                    tone: DgTone.warn,
                    icon: LucideIcons.zap,
                    dense: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            row.recipientName,
            style: Dg.ui(size: 17, weight: FontWeight.w700),
          ),
          if (row.district.isNotEmpty || row.addressLine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  row.addressLine,
                  row.district,
                ].where((e) => e.isNotEmpty).join(' · '),
                style: Dg.ui(size: 14, color: Dg.text2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Müşteri, sözleşme, sipariş / referans no ve SLA durumu (etiket satırı).
/// Not alanı şube uçlarında yok; dürüstçe belirtilir.
class _CustomerBlock extends StatelessWidget {
  const _CustomerBlock({required this.row, required this.label});

  final BranchShipmentRow row;
  final Future<Map<String, dynamic>?> label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder(
      future: label,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const DgSkeleton(height: 72, radius: 12);
        }
        final data = snap.data;
        if (data == null) return DgPendingBackend(what: l.customerSlaWhat);
        String text(Object? v) => v is String ? v.trim() : '';
        final customer = data['customer'] is Map
            ? text((data['customer'] as Map)['name'])
            : '';
        final sla = text(data['slaStatusCode']);
        return Column(
          children: [
            DgInfoRow(
              icon: LucideIcons.building2,
              label: l.fieldCustomer,
              value: customer,
            ),
            if (text(data['contractName']).isNotEmpty)
              DgInfoRow(
                icon: LucideIcons.fileText,
                label: l.slaContract,
                value: text(data['contractName']),
              ),
            if (text(data['orderNumber']).isNotEmpty)
              DgInfoRow(
                icon: LucideIcons.hash,
                label: l.slaOrder,
                value: text(data['orderNumber']),
              ),
            if (text(data['referenceNo']).isNotEmpty)
              DgInfoRow(
                icon: LucideIcons.hash,
                label: l.slaReference,
                value: text(data['referenceNo']),
              ),
            DgInfoRow(
              icon: LucideIcons.timer,
              label: 'SLA',
              value: row.late ? l.slaBreached : sla,
              trailing: row.late
                  ? Icon(LucideIcons.clockAlert, size: 16, color: Dg.bad)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion});

  final CourierSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = suggestion;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          InitialsAvatar(name: s.name, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: Dg.ui(size: 15, weight: FontWeight.w600)),
                Text(
                  [
                    l.activeJobs(s.activeJobs),
                    if (s.etaMinutes != null) l.etaMinutes(s.etaMinutes!),
                    if (s.area.isNotEmpty) s.area,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Dg.ui(size: 13, color: Dg.text3),
                ),
              ],
            ),
          ),
          DgStatusPill(
            label: l.regionFit(s.regionFit),
            tone: switch (s.regionFit) {
              'MATCH' => DgTone.ok,
              'PARTIAL' => DgTone.info,
              _ => DgTone.warn,
            },
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Appear(
        child: DgPanel(
          child: Row(
            children: [
              const DgIconBadge(
                icon: LucideIcons.info,
                tone: DgTone.warn,
                size: 36,
                soft: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: Dg.ui(size: 14, color: Dg.text2)),
              ),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: Text(l.retryNow)),
            ],
          ),
        ),
      ),
    );
  }
}
