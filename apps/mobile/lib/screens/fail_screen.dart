import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/courier_tasks.dart';
import '../l10n.dart';
import '../media_upload.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'result_screen.dart';

/// Dedicated "teslim edilemedi" reason picker, reached from [TaskDetailScreen]
/// and from the delivery wizard's "Teslim edemedim" button.
class FailScreen extends ConsumerStatefulWidget {
  const FailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<FailScreen> createState() => _FailScreenState();
}

class _FailScreenState extends ConsumerState<FailScreen> {
  static const reasons = [
    'Adres bulunamadı',
    'Alıcı adreste yok',
    'Alıcı teslim almadı',
    'Ödeme alınamadı',
    'Adres hatalı',
    'Siteye giriş izni yok',
  ];

  String? picked;
  final note = TextEditingController();
  bool closed = false;
  bool photo = false;
  bool uploading = false;
  String? photoMediaId;

  bool get _photoRequired =>
      picked != null && photoRequiredForFailure(picked!);

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
    final s = ref.watch(sessionProvider);
    final task = s.taskById(widget.taskId);

    if (closed) {
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
        title: Mono(
          task.ref,
          size: 13,
          weight: FontWeight.w700,
          color: Dg.ink2,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Display(l.whyFailed, size: 28),
          const SizedBox(height: 8),
          Text(
            l.whyFailedBody,
            style: TextStyle(color: Dg.ink2, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          for (final r in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DgChoiceSurface(
                selected: picked == r,
                onTap: () => setState(() => picked = r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                      ref
                          .read(sessionProvider)
                          .returnTask(
                            widget.taskId,
                            reason: picked!,
                            note: note.text.trim(),
                            photoMediaId: photoMediaId,
                          );
                      setState(() => closed = true);
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}
