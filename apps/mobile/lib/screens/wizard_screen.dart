import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../media_upload.dart';
import '../motion.dart';
import '../session.dart';
import '../signature.dart';
import '../privacy.dart';
import '../theme.dart';
import '../widgets.dart';
import 'fail_screen.dart';
import 'kyc_screen.dart';
import 'result_screen.dart';

class WizardScreen extends ConsumerStatefulWidget {
  const WizardScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends ConsumerState<WizardScreen> {
  int step = 0;
  String? recipient;
  String proof = 'photo';
  bool photo = false;
  String? photoMediaId;
  String? signMediaId;
  SignatureCapture? signature;
  final _pad = GlobalKey<SignaturePadState>();
  bool otpSent = false;
  final otp = TextEditingController();
  String? error;
  bool done = false;

  // Getter, not `static const` — the tint/ink pair (Dg.violetBg, ...) reads
  // Dg.dark at call time, so this must re-evaluate on every access instead
  // of being frozen at first use (otherwise it'd go stale after a
  // koyu/açık tema toggle).
  static List<(String, String, IconData, Color, Color)> optionsFor(L10n l) => [
    ('recipient', l.recipientSelf, LucideIcons.user, Dg.violetBg, Dg.violet),
    ('relative', l.familyMember, LucideIcons.users, Dg.blueBg, Dg.blue),
    ('neighbor', l.neighbor, LucideIcons.doorOpen, Dg.amberBg, Dg.amber),
    (
      'workplace',
      l.workplace,
      LucideIcons.building2,
      Dg.greenBg,
      Dg.green,
    ),
  ];

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  bool get proofDone =>
      proof == 'photo' ? photo : signature != null && !signature!.isEmpty;

  String whoLabel(L10n l) => optionsFor(l)
      .firstWhere(
        (o) => o.$1 == recipient,
        orElse: () => ('', '—', LucideIcons.circle, Dg.elev, Dg.ink),
      )
      .$2;

  String cta(L10n l) {
    if (step == 1 && proofDone) return l.usePhoto;
    if (step == 2) return otpSent ? l.verifyAndDeliver : l.sendCodeCta;
    return l.continueLabel;
  }

  Future<void> _next() async {
    final l = context.l10n;
    final s = ref.read(sessionProvider);
    setState(() => error = null);
    if (step == 0 && recipient == null) {
      setState(() => error = l.pickRecipient);
      return;
    }
    if (step == 1 && !proofDone) {
      setState(() => error = l.proofNeeded);
      return;
    }
    if (step == 0) {
      s.submitStep(
        taskId: widget.taskId,
        stepKey: 'varis_kontrolu',
        skipReasonCode: 'GPS_UNAVAILABLE',
        status: 'completed',
      );
      s.submitStep(
        taskId: widget.taskId,
        stepKey: 'barkod_okut',
        value: {'code': s.taskById(widget.taskId).ref},
      );
      s.submitStep(
        taskId: widget.taskId,
        stepKey: 'alici_kim',
        value: {
          'teslim_alan': recipient,
          'teslim_alan_ad': s.taskById(widget.taskId).recipient,
        },
      );
    }
    if (step == 1) {
      if (proof == 'photo' && photoMediaId != null) {
        s.submitStep(
          taskId: widget.taskId,
          stepKey: 'teslim_fotografi',
          mediaIds: [photoMediaId!],
        );
      }
      if (proof == 'sign') {
        signMediaId ??= await uploadEvidence(
          api: s.api,
          bytes: tinyPng(),
          kind: 'signature',
          contentType: 'image/png',
          taskId: widget.taskId,
          stepKey: 'alici_imza',
        );
        if (signMediaId != null) {
          s.submitStep(
            taskId: widget.taskId,
            stepKey: 'alici_imza',
            value: signature?.toProof(),
            mediaIds: [signMediaId!],
          );
        }
      }
    }
    if (step == 2) {
      if (!otpSent) {
        final sent = await s.sendDeliveryOtp(widget.taskId);
        if (!mounted) return;
        if (!sent) {
          setState(() => error = l.otpMismatchAsk);
          return;
        }
        setState(() => otpSent = true);
        return;
      }
      if (!await s.verifyDeliveryOtp(widget.taskId, otp.text.trim())) {
        if (!mounted) return;
        setState(() => error = l.otpMismatchAsk);
        return;
      }
      if (recipient == 'recipient' && s.taskById(widget.taskId).otpRequired) {
        s.submitStep(
          taskId: widget.taskId,
          stepKey: 'otp_dogrula',
          value: {'verificationToken': s.deliveryOtpToken},
        );
      }
      s.deliverTask(
        widget.taskId,
        receivedBy: whoLabel(l),
        proof: proof == 'sign'
            ? signature?.toProof()
            : const {
                'type': 'DOOR_PHOTO',
                'channel': 'CAMERA_CAPTURE',
                'btk': {'status': 'PENDING_INTEGRATION', 'qualified': false},
              },
      );
      setState(() => done = true);
      return;
    }
    setState(() => step += 1);
  }

  Future<void> _goFail() async {
    final failed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FailScreen(taskId: widget.taskId),
      ),
    );
    if (failed == true && mounted)
      Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final task = s.taskById(widget.taskId);

    final l = context.l10n;

    if (done) {
      return DeliveryResultScreen(
        success: true,
        task: task,
        who: whoLabel(l),
        online: s.online,
        next: s.nextStop,
        onClose: () => Navigator.popUntil(context, (r) => r.isFirst),
        onNext: () {
          final n = ref.read(sessionProvider).nextStop;
          Navigator.popUntil(context, (r) => r.isFirst);
          if (n == null) return;
          ref.read(sessionProvider).startTask(n.id);
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => WizardScreen(taskId: n.id)),
          );
        },
      );
    }

    final titles = [l.recipient, l.proof, l.deliveryCode];
    return PrivacyGate(
      active: otpSent,
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titles[step]),
            Text(
              '${l.stepOf(step + 1, 3)}  ·  ${task.ref}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Dg.ink3,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: i <= step ? Dg.primaryGradient : null,
                        color: i <= step ? null : Dg.elev,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                DgCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        name: task.recipient,
                        photoUrl: task.personPhoto,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.recipient,
                              style: Dg.ui(size: 16, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Mono(
                              '${task.ref}  ·  ${task.window}',
                              size: 12,
                              color: Dg.ink3,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Dg.ui(size: 12, color: Dg.ink3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (step == 0) ...[
                  Text(
                    l.whoReceived,
                    style: Dg.ui(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Dg.ink2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, o) in optionsFor(l).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: StaggerIn(
                        index: i,
                        child: DgChoiceSurface(
                          selected: recipient == o.$1,
                          onTap: () => setState(() => recipient = o.$1),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                IconTintBadge(
                                  icon: o.$3,
                                  tint: o.$4,
                                  ink: o.$5,
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    o.$2,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                DgSelectMark(selected: recipient == o.$1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                if (step == 1) ...[
                  SegmentedTabs(
                    labels: [l.photoFull, l.signature],
                    index: proof == 'photo' ? 0 : 1,
                    onChanged: (i) =>
                        setState(() => proof = i == 0 ? 'photo' : 'sign'),
                  ),
                  const SizedBox(height: 16),
                  if (proof == 'photo') ...[
                    Viewfinder(
                      captured: photo,
                      onCapture: (path) async {
                        setState(() => photo = true);
                        final id = await uploadFileEvidence(
                          api: ref.read(sessionProvider).api,
                          path: path,
                          kind: 'photo',
                          taskId: widget.taskId,
                          stepKey: 'teslim_fotografi',
                        );
                        if (mounted) setState(() => photoMediaId = id);
                      },
                    ),
                    if (photo)
                      TextButton(
                        onPressed: () => setState(() => photo = false),
                        child: Text(l.retake),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Dg.elev,
                        borderRadius: BorderRadius.circular(Dg.radius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.declaration,
                            style: TextStyle(
                              fontSize: 13,
                              color: Dg.ink2,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const DgDivider(),
                          const SizedBox(height: 10),
                          _declarationRow(l.shipmentNo, task.ref),
                          _declarationRow(l.recipientName, task.recipient),
                          _declarationRow(l.date, _now()),
                        ],
                      ),
                    ),
                    SignaturePad(
                      key: _pad,
                      hint: l.signHere,
                      onChanged: (cap) => setState(() => signature = cap),
                    ),
                    if (proofDone) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Dg.sage,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.signedOnField,
                              style: Dg.ui(size: 13, color: Dg.ink2),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _pad.currentState?.clear();
                              setState(() => signature = null);
                            },
                            child: Text(l.clear),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
                if (step == 2) ...[
                  DgCard(
                    dark: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            LucideIcons.key,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.askFourDigit,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          otpSent ? l.otpSentToRecipient : l.otpWillSend,
                          style: const TextStyle(
                            color: Color(0xFF9A9E90),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (otpSent) ...[
                    const SizedBox(height: 16),
                    OtpPin(controller: otp, error: error != null),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(() {}),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.resendCode,
                              style: Dg.ui(
                                size: 14,
                                weight: FontWeight.w600,
                                color: Dg.primaryGradientStart,
                              ),
                            ),
                          ),
                          Mono('00:24', size: 13, color: Dg.ink3),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const DgDivider(),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const KycScreen(),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.verifyWithId,
                              style: Dg.ui(size: 14, color: Dg.ink2),
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: Dg.ink3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ShakeError(
                      trigger: error,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Dg.hi,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Material(
            color: Dg.surface,
            elevation: 8,
            shadowColor: const Color(0x1412191A),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    DgButton(
                      label: cta(l),
                      trailing: LucideIcons.arrowRight,
                      onPressed: _next,
                    ),
                    TextButton(
                      onPressed: _goFail,
                      child: Text(
                        l.couldNotDeliver,
                        style: TextStyle(
                          color: Dg.hi,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _declarationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: Dg.ink3)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _now() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.day)}.${two(n.month)}.${n.year} ${two(n.hour)}:${two(n.minute)}';
  }
}
