import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/courier_tasks.dart';
import '../api/models.dart';
import '../l10n.dart';
import '../media_upload.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result_screen.dart';

/// İade / Geri Teslim — akış şemasının Kurye app modül 8'i. İki sekme:
/// "Teslim Edilemedi" (neden seç, not, fotoğraf — teslimat sonucunu
/// raporlar) ve "Geri Teslim" (elindeki kalemi fiziksel olarak şubeye
/// bırakır). Önceden ayrı ekranlardı (`fail_screen.dart` + `zimmet_screen.dart`
/// şube modu, ikinci menü/tara girişinden ayrı ulaşılıyordu); bu ekran ikisini
/// aynı yerde, tek görev bağlamında bir araya getiriyor.
class ReturnScreen extends ConsumerStatefulWidget {
  const ReturnScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends ConsumerState<ReturnScreen> {
  int _tab = 0;
  bool _failClosed = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final task = s.taskOrNull(widget.taskId);
    if (task == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.stopGone)));
    }

    if (_failClosed) {
      return DeliveryResultScreen(
        success: false,
        task: task,
        online: s.online,
        next: null,
        onClose: () => Navigator.of(context).pop(true),
        onNext: () {},
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Mono(task.ref, size: 13, weight: FontWeight.w700, color: Dg.ink2),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: SegmentedTabs(
                labels: [l.whyFailed, l.returnToBranchTab],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _FailReasonPane(
                    taskId: widget.taskId,
                    onClosed: () => setState(() => _failClosed = true),
                  ),
                  _GeriTeslimPane(taskId: widget.taskId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailReasonPane extends ConsumerStatefulWidget {
  const _FailReasonPane({required this.taskId, required this.onClosed});

  final String taskId;
  final VoidCallback onClosed;

  @override
  ConsumerState<_FailReasonPane> createState() => _FailReasonPaneState();
}

class _FailReasonPaneState extends ConsumerState<_FailReasonPane> {
  // Not: "Ödeme alınamadı" kasıtlı olarak listede yok — kapıda ödeme (COD)
  // tamamen kaldırıldı, kurye artık teslimatta nakit/kart tahsilatı yapmıyor.
  static const reasons = [
    'Adres bulunamadı',
    'Alıcı adreste yok',
    'Alıcı teslim almadı',
    'Adres hatalı',
    'Siteye giriş izni yok',
  ];

  String? picked;
  final note = TextEditingController();
  bool photo = false;
  bool uploading = false;
  String? photoMediaId;

  bool get _photoRequired => picked != null && photoRequiredForFailure(picked!);

  bool get _canSubmit =>
      picked != null && !uploading && (!_photoRequired || photoMediaId != null);

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          l.whyFailedBody,
          style: TextStyle(color: Dg.ink2, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 16),
        for (final r in reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DgChoiceSurface(
              selected: picked == r,
              onTap: () => setState(() => picked = r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.failReasonOf(r),
                        style: Dg.ui(
                          size: 16,
                          weight: FontWeight.w600,
                          color: picked == r ? Dg.red : Dg.ink,
                        ),
                      ),
                    ),
                    DgSelectMark(selected: picked == r),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        DgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Mono(l.extraNote, size: 11, color: Dg.ink3),
              const SizedBox(height: 6),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: l.optionalNote,
                ),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Viewfinder(
          captured: photo,
          hint: _photoRequired ? l.proofPhotoRequired : l.proofNeeded,
          onCapture: (path) async {
            setState(() {
              photo = true;
              uploading = true;
            });
            final id = await uploadFileEvidence(
              api: ref.read(sessionProvider).api,
              path: path,
              kind: 'photo',
              taskId: widget.taskId,
              stepKey: failureOutcomeCode(picked ?? '') == 'ADDRESS_NOT_FOUND'
                  ? 'adres_kanit_fotografi'
                  : 'yok_kanit_fotografi',
            );
            if (mounted) {
              setState(() {
                photoMediaId = id;
                uploading = false;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        if (picked != null)
          DgButton(
            label: l.closeAsReturn,
            icon: LucideIcons.packageX,
            tone: DgButtonTone.danger,
            busy: uploading,
            onPressed: _canSubmit
                ? () {
                    ref.read(sessionProvider).returnTask(
                      widget.taskId,
                      reason: picked!,
                      note: note.text.trim(),
                      photoMediaId: photoMediaId,
                    );
                    widget.onClosed();
                  }
                : null,
          ),
      ],
    );
  }
}

/// Elindeki kalemi doğrudan şubeye bırakır — barkod okutmaya gerek yok,
/// kalem zaten bu görevle eşleşmiş durumda (bkz.
/// `SessionController.returnTaskToBranch`).
class _GeriTeslimPane extends ConsumerStatefulWidget {
  const _GeriTeslimPane({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_GeriTeslimPane> createState() => _GeriTeslimPaneState();
}

class _GeriTeslimPaneState extends ConsumerState<_GeriTeslimPane> {
  bool _done = false;
  bool _failed = false;
  // Başarılı teslimden sonra kalem `custodyItems`'tan silinir — o andaki
  // görünümü korumak için ayrıca tutuluyor.
  CustodyItemDto? _completedItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).loadCustody();
    });
  }

  Future<void> _submit(CustodyItemDto item) async {
    final s = ref.read(sessionProvider);
    final ok = await s.returnTaskToBranch(widget.taskId);
    if (!mounted) return;
    setState(() {
      _done = ok;
      _failed = !ok;
      if (ok) _completedItem = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final item = _completedItem ?? s.custodyItemForTask(widget.taskId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          l.branchHandoverHint,
          style: TextStyle(color: Dg.ink2, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (item != null)
          DgCard(
            child: Row(
              children: [
                DgIcon(LucideIcons.package, color: Dg.brand, weight: 600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description, style: Dg.ui(size: 15, weight: FontWeight.w600)),
                      if (item.barcode != null) ...[
                        const SizedBox(height: 2),
                        Mono(item.barcode!, size: 12, color: Dg.ink3),
                      ],
                    ],
                  ),
                ),
                if (_done)
                  Icon(LucideIcons.checkCircle2, color: Dg.ok),
              ],
            ),
          )
        else if (s.custodyLoading)
          const Center(child: CircularProgressIndicator())
        else
          Text(l.branchHandoverNotFound, style: Dg.ui(size: 14, color: Dg.ink3)),
        if (_failed) ...[
          const SizedBox(height: 12),
          Text(l.handoverFailed, style: Dg.ui(size: 13, color: Dg.hi)),
        ],
        const SizedBox(height: 20),
        if (item != null && !_done)
          DgButton(
            label: l.branchHandoverConfirm,
            icon: LucideIcons.building2,
            tone: DgButtonTone.brand,
            busy: s.custodyHandoverPending,
            onPressed: s.custodyHandoverPending ? null : () => _submit(item),
          ),
      ],
    );
  }
}
