import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../api/branch_proposed_models.dart';
import '../branch_features.dart';
import '../launchers.dart';
import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import '../widgets.dart';
import 'sube_more_screens.dart';
import 'sube_widgets.dart';

String _date(DateTime at) {
  final t = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year}';
}

String _money(L10n l, num v) {
  final whole = v.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return l.isEn ? '₺$whole' : '$whole ₺';
}

/// İş Ortaklığı Evrakları + Dağıtım Planlama (mockup 21): şube sözleşme ve
/// evrak kalemleri uyum ucundan gelir; uç hazır değilken her kalem
/// "Bekleniyor" görünür (uydurma durum yok). Dağıtım planlama talebi
/// önerilen uca bağlı (docs/15 §7); bayrak kapalıyken dürüst boş durum.
class SubePartnerDocsScreen extends ConsumerStatefulWidget {
  const SubePartnerDocsScreen({super.key});

  @override
  ConsumerState<SubePartnerDocsScreen> createState() =>
      _SubePartnerDocsScreenState();
}

class _SubePartnerDocsScreenState extends ConsumerState<SubePartnerDocsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final branch = ref.read(sessionProvider).branch;
      branch.loadCompliance();
      branch.loadDistributionPlans();
    });
  }

  static DgTone _tone(String status) => switch (status) {
    'SIGNED' || 'APPROVED' => DgTone.ok,
    'IN_REVIEW' || 'PENDING' => DgTone.warn,
    'MISSING' || 'EXPIRED' || 'REJECTED' => DgTone.bad,
    _ => DgTone.neutral,
  };

  String? _validity(L10n l, PartnerDocItem d) =>
      d.expiresAt == null ? null : l.docValidUntil(_date(d.expiresAt!));

  VoidCallback? _opener(PartnerDocItem d) {
    final url = d.fileUrl;
    if (url == null) return null;
    return () => openLink(context, url);
  }

  Future<void> _newPlan() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Dg.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: _PlanSheet()),
    );
    if (sent == true && mounted) subeSnack(context, context.l10n.planSent);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final docs = branch.branchDocs;
    DgStatus status(String code) => (
      label: l.partnerDocStatus(code),
      tone: _tone(code),
      icon: switch (_tone(code)) {
        DgTone.ok => LucideIcons.circleCheck,
        DgTone.warn => LucideIcons.hourglass,
        DgTone.bad => LucideIcons.circleAlert,
        _ => LucideIcons.cloudCog,
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.partnerDocsTitle)),
      body: RefreshIndicator(
        onRefresh: branch.loadCompliance,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SubeStatusBanner(branch: branch, onRetry: branch.loadCompliance),
            if (docs == null)
              branch.loading
                  ? const DgSkeleton(height: 200, radius: 16)
                  : const SizedBox.shrink()
            else ...[
              if (!docs.schemaReady) ...[
                DgPendingBackend(what: l.partnerDocsWhat),
                const SizedBox(height: 12),
              ],
              DgPanel(
                title: l.secContracts,
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
                child: Column(
                  children: [
                    for (final c in docs.contracts)
                      DgDocRow(
                        icon: LucideIcons.fileSignature,
                        title: l.contractType(c.type),
                        subtitle: _validity(l, c),
                        status: status(c.status),
                        onTap: _opener(c),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DgPanel(
                title: l.secBranchDocs,
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
                child: Column(
                  children: [
                    for (final d in docs.documents)
                      DgDocRow(
                        icon: LucideIcons.fileText,
                        title: l.branchDocType(d.type),
                        subtitle: _validity(l, d),
                        status: status(d.status),
                        onTap: _opener(d),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l.distributionPlanTitle,
              style: Dg.ui(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (branch.proposed(BranchFeatures.distributionPlanning))
              _DistributionPlans(
                plans: branch.distributionPlans,
                onNew: branch.capabilities.operate ? _newPlan : null,
              )
            else
              DgPendingBackend(what: l.distributionPlanWhat),
          ],
        ),
      ),
    );
  }
}

/// Fatura & Hakediş (mockup 19): faturalar ve destek talepleri. Canlı uçta
/// fatura modeli yok (`schemaReady: false`, liste hep boş) → dürüst boş
/// durum; demo örnek faturayla dolar. Destek talepleri gerçek uçtan.
class SubeBillingScreen extends ConsumerStatefulWidget {
  const SubeBillingScreen({super.key});

  @override
  ConsumerState<SubeBillingScreen> createState() => _SubeBillingScreenState();
}

class _SubeBillingScreenState extends ConsumerState<SubeBillingScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(sessionProvider).branch.loadInvoices(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final demo = branch.demo;
    final invoices = branch.invoices ?? const <BranchInvoice>[];
    final open = invoices
        .where((i) => i.status != 'PAID')
        .fold<num>(0, (a, i) => a + i.amount + i.vat);
    final paid = invoices
        .where((i) => i.status == 'PAID')
        .fold<num>(0, (a, i) => a + i.amount + i.vat);
    return Scaffold(
      appBar: AppBar(title: Text(l.invoicesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          DgPillTabs(
            labels: [l.invoiceTabList, l.invoiceTabSupport],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) ...[
            if (invoices.isEmpty)
              branch.loading && branch.invoices == null
                  ? const DgSkeleton(height: 160, radius: 16)
                  : DgPendingBackend(what: l.invoicesWhat)
            else ...[
              DgPanel(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _Money(
                        label: l.earningsOpen,
                        value: _money(l, open),
                        tone: DgTone.warn,
                      ),
                    ),
                    Container(width: 1, height: 44, color: Dg.hairline),
                    Expanded(
                      child: _Money(
                        label: l.earningsPaid,
                        value: _money(l, paid),
                        tone: DgTone.ok,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < invoices.length; i++)
                StaggerIn(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DgPanel(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SubeInvoiceDetailScreen(invoice: invoices[i]),
                        ),
                      ),
                      child: Row(
                        children: [
                          DgIconBadge(
                            icon: LucideIcons.receiptText,
                            tone: invoices[i].status == 'PAID'
                                ? DgTone.ok
                                : DgTone.warn,
                            soft: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoices[i].number,
                                  style: Dg.ui(
                                    size: 15,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${l.invoicePeriod} ${invoices[i].period} · '
                                  '${l.invoiceDue} ${_date(invoices[i].due)}',
                                  style: Dg.typeCaption(),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _money(l, invoices[i].amount + invoices[i].vat),
                                style: Dg.ui(size: 15, weight: FontWeight.w700),
                              ),
                              DgStatusPill(
                                label: l.invoiceStatus(invoices[i].status),
                                tone: invoices[i].status == 'PAID'
                                    ? DgTone.ok
                                    : DgTone.warn,
                                dense: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ] else ...[
            if (demo)
              DgPendingBackend(what: l.invoiceTabSupport)
            else
              DgPanel(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SubeInvoicesScreen(),
                  ),
                ),
                child: Row(
                  children: [
                    const DgIconBadge(
                      icon: LucideIcons.messageSquareText,
                      tone: DgTone.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.invoiceNewRequest,
                        style: Dg.ui(size: 15, weight: FontWeight.w600),
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, size: 18, color: Dg.text3),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final DgTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Dg.stat(
              size: 20,
              weight: FontWeight.w700,
              color: dgToneColor(tone),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Dg.typeCaption()),
      ],
    );
  }
}

/// Fatura Detayı (mockup 20): canlıda `branch/invoices` fatura modeli
/// gelince dolar (docs/15 §2); PDF bağlantısı varsa açılır.
class SubeInvoiceDetailScreen extends StatelessWidget {
  const SubeInvoiceDetailScreen({super.key, required this.invoice});

  final BranchInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final i = invoice;
    return Scaffold(
      appBar: AppBar(title: Text(l.invoiceDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          DgPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.number,
                        style: Dg.ui(size: 18, weight: FontWeight.w800),
                      ),
                    ),
                    DgStatusPill(
                      label: l.invoiceStatus(i.status),
                      tone: i.status == 'PAID' ? DgTone.ok : DgTone.warn,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _money(l, i.amount + i.vat),
                  style: Dg.stat(size: 30, weight: FontWeight.w700),
                ),
                Text(l.invoiceTotal, style: Dg.typeCaption()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DgPanel(
            child: Column(
              children: [
                DgInfoRow(label: l.invoicePeriod, value: i.period),
                DgInfoRow(label: l.invoiceDue, value: _date(i.due)),
                DgInfoRow(label: l.invoiceAmount, value: _money(l, i.amount)),
                DgInfoRow(label: l.invoiceVat, value: _money(l, i.vat)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DgPanel(
            title: l.invoiceLines,
            child: Column(
              children: [
                for (final line in i.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.label} × ${line.quantity}',
                            style: Dg.ui(size: 15),
                          ),
                        ),
                        Text(
                          _money(l, line.amount),
                          style: Dg.ui(size: 15, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (i.pdfUrl != null) ...[
            const SizedBox(height: 16),
            DgButton(
              label: l.invoicePdf,
              icon: LucideIcons.fileDown,
              tone: DgButtonTone.secondary,
              onPressed: () => openLink(context, i.pdfUrl!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hızlı Gönder (mockup 23): telefonda bekleyen şube okutmaları, son
/// eşitleme ve "Hemen gönder". Okutmalar önce kuyruğa yazılır, bağlantı
/// gelince sırayla gider; burada yalnız kuyruğun gerçek durumu görünür.
class SubeOfflineScreen extends ConsumerStatefulWidget {
  const SubeOfflineScreen({super.key});

  @override
  ConsumerState<SubeOfflineScreen> createState() => _SubeOfflineScreenState();
}

class _SubeOfflineScreenState extends ConsumerState<SubeOfflineScreen> {
  bool _busy = false;

  Future<void> _send() async {
    final l = context.l10n;
    final branch = ref.read(sessionProvider).branch;
    setState(() => _busy = true);
    await branch.flush();
    if (!mounted) return;
    setState(() => _busy = false);
    final left = branch.pendingScans;
    subeSnack(context, left == 0 ? l.offlineAllSent : l.offlineStill(left));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final events = [
      for (final e in branch.outbox.events)
        if (e.operation.isBranch) e,
    ]..sort((a, b) => b.sequence.compareTo(a.sequence));
    final pending = events.where((e) => e.pending).length;
    final synced = branch.syncedAt;
    return Scaffold(
      appBar: AppBar(title: Text(l.offlineTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          DgPanel(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                DgIconBadge(
                  icon: pending == 0
                      ? LucideIcons.cloudCheck
                      : LucideIcons.cloudUpload,
                  tone: pending == 0 ? DgTone.ok : DgTone.warn,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pending == 0
                            ? l.offlineAllSent
                            : l.offlinePending(pending),
                        style: Dg.ui(size: 16, weight: FontWeight.w700),
                      ),
                      Text(
                        synced == null
                            ? l.offlineNeverSynced
                            : l.offlineLastSync(subeClock(synced)),
                        style: Dg.typeCaption(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(l.offlineHint, style: Dg.typeCaption()),
          const SizedBox(height: 12),
          DgGradientButton(
            key: const Key('offline-send'),
            label: l.offlineSendNow,
            icon: LucideIcons.send,
            busy: _busy,
            onPressed: pending == 0 || _busy ? null : _send,
          ),
          const SizedBox(height: 16),
          if (events.isNotEmpty)
            DgPanel(
              title: l.offlineHistory,
              child: Column(
                children: [
                  for (final e in events.take(30))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.payload['barcode'] ?? '—'}',
                                  style: Dg.ui(
                                    size: 15,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${l.syncOpLabel(e.operation.wire)} · '
                                  '${subeClock(e.occurredAt)}',
                                  style: Dg.typeCaption(),
                                ),
                              ],
                            ),
                          ),
                          DgStatusPill(
                            label: l.syncStatus(e.status),
                            tone: switch (e.status) {
                              'applied' => DgTone.ok,
                              'rejected' => DgTone.bad,
                              _ => DgTone.warn,
                            },
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Dağıtım planlama talepleri ve "Yeni talep" (docs/15 §7).
class _DistributionPlans extends StatelessWidget {
  const _DistributionPlans({required this.plans, required this.onNew});

  final List<DistributionPlan>? plans;
  final VoidCallback? onNew;

  static DgTone _tone(String status) => switch (status) {
    'APPROVED' || 'SCHEDULED' => DgTone.ok,
    'REJECTED' => DgTone.bad,
    _ => DgTone.warn,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = plans;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows == null)
          const DgSkeleton(height: 72, radius: 16)
        else if (rows.isEmpty)
          DgPanel(child: Text(l.planEmpty, style: Dg.typeCaption()))
        else
          DgPanel(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Column(
              children: [
                for (final p in rows)
                  DgDocRow(
                    icon: LucideIcons.calendarRange,
                    title: '${p.district} · ${_day(p.date)}',
                    subtitle: [
                      l.planVolumeShort(p.expectedVolume),
                      if (p.note.isNotEmpty) p.note,
                    ].join(' · '),
                    status: (
                      label: l.planStatus(p.status),
                      tone: _tone(p.status),
                      icon: LucideIcons.calendarCheck,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        DgButton(
          key: const Key('plan-new'),
          label: l.planNew,
          icon: LucideIcons.plus,
          tone: DgButtonTone.secondary,
          onPressed: onNew,
        ),
      ],
    );
  }

  static String _day(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : _date(d);
  }
}

class _PlanSheet extends ConsumerStatefulWidget {
  const _PlanSheet();

  @override
  ConsumerState<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<_PlanSheet> {
  final _district = TextEditingController();
  final _volume = TextEditingController();
  final _note = TextEditingController();
  DateTime _day = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _district.dispose();
    _volume.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(sessionProvider)
        .branch
        .createDistributionPlan(
          date: _day,
          district: _district.text,
          expectedVolume: int.tryParse(_volume.text.trim()) ?? 0,
          note: _note.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.distributionPlanTitle,
            style: Dg.ui(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(l.planDate, style: Dg.ui(size: 13, color: Dg.ink3)),
          const SizedBox(height: 4),
          DgButton(
            label: _date(_day),
            icon: LucideIcons.calendar,
            tone: DgButtonTone.secondary,
            onPressed: _pickDate,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('plan-district'),
            controller: _district,
            decoration: InputDecoration(hintText: l.planDistrict),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('plan-volume'),
            controller: _volume,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: l.planVolume),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: 300,
            decoration: InputDecoration(hintText: l.planNote),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(
                color: Dg.hi,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 10),
          DgButton(
            key: const Key('plan-send'),
            label: l.planSend,
            busy: _busy,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
