import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../branch_features.dart';
import '../l10n.dart';
import '../models.dart';
import '../motion.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/ui.dart';
import 'sube_demo.dart';
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
/// "Bekleniyor" görünür (uydurma durum yok). Dağıtım planlama talebi uç
/// gelene kadar dürüst boş durum.
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
      ref.read(sessionProvider).branch.loadCompliance();
    });
  }

  static DgTone _tone(String status) => switch (status) {
    'SIGNED' || 'APPROVED' => DgTone.ok,
    'IN_REVIEW' || 'PENDING' => DgTone.warn,
    'MISSING' || 'EXPIRED' || 'REJECTED' => DgTone.bad,
    _ => DgTone.neutral,
  };

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
                        status: status(c.status),
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
                        status: status(d.status),
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
            if (!BranchFeatures.distributionPlanning)
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    final demo = ref.watch(sessionProvider).branch.demo;
    final invoices = demo && BranchFeatures.invoices == false
        ? kSubeDemoInvoices
        : const <DemoInvoice>[];
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
              DgPendingBackend(what: l.invoicesWhat)
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

/// Fatura Detayı (mockup 20): yalnız demo örneği; canlıda fatura modeli
/// yok.
class SubeInvoiceDetailScreen extends StatelessWidget {
  const SubeInvoiceDetailScreen({super.key, required this.invoice});

  final DemoInvoice invoice;

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
