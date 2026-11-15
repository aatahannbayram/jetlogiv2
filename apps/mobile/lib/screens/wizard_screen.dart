import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../media_upload.dart';
import '../models.dart';
import '../motion.dart';
import '../scan.dart';
import '../session.dart';
import '../signature.dart';
import '../privacy.dart';
import '../theme.dart';
import '../widgets.dart';
import 'return_screen.dart';
import 'kyc_screen.dart';
import 'result_screen.dart';
import 'support_screen.dart';
import 'visit_flow_screen.dart';

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
  bool otpVerified = false;
  bool otpBusy = false;
  int otpSends = 0;
  int resendLeft = 0;
  Timer? _resendTimer;
  final otp = TextEditingController();
  final otherName = TextEditingController();
  final otherRelation = TextEditingController();
  final otherNote = TextEditingController();

  /// V3 §5.3: bekleme ve limit panelden gelmezse bu varsayılanlar.
  // Swagger 1.6: yeniden gönderim 60 sn, gönderi başına saatte 5 kod.
  static const _resendSeconds = 60;
  static const _maxSends = 5;
  String? error;
  bool done = false;
  bool submitting = false;
  bool confirmed = false;
  bool _requirementsReady = false;

  @override
  void initState() {
    super.initState();
    otp.addListener(_onOtpChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(sessionProvider).resetIdentityCheck();
      await ref.read(sessionProvider).loadTaskRequirements(widget.taskId);
      if (mounted) setState(() => _requirementsReady = true);
    });
  }

  // Getter, not `static const` — the tint/ink pair (Dg.violetBg, ...) reads
  // Dg.dark at call time, so this must re-evaluate on every access instead
  // of being frozen at first use (otherwise it'd go stale after a
  // koyu/açık tema toggle).
  /// V3 §3.1 teslim alan seçenekleri. Komşu varsayılan kapalı (§19.2).
  /// Kart/kişiye özel teslimde yalnız Kendisi ve Banka/Kurum yetkilisi.
  static List<(String, String, IconData, Color, Color)> optionsFor(
    L10n l, {
    bool card = false,
  }) {
    final self = (
      'recipient',
      l.rcvSelf,
      LucideIcons.user,
      Dg.violetBg,
      Dg.violet,
    );
    final bank = (
      'bank',
      l.rcvInstitution,
      LucideIcons.landmark,
      Dg.blueBg,
      Dg.blue,
    );
    if (card) return [self, bank];
    return [
      self,
      ('relative', l.rcvRelative, LucideIcons.users, Dg.blueBg, Dg.blue),
      (
        'authorized',
        l.rcvAuthorized,
        LucideIcons.clipboardCheck,
        Dg.greenBg,
        Dg.green,
      ),
      (
        'workplace',
        l.rcvSecretary,
        LucideIcons.briefcase,
        Dg.greenBg,
        Dg.green,
      ),
      ('security', l.rcvSecurity, LucideIcons.shield, Dg.amberBg, Dg.amber),
      bank,
      ('other', l.rcvOther, LucideIcons.ellipsis, Dg.amberBg, Dg.amber),
    ];
  }

  void _onOtpChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    otp.removeListener(_onOtpChanged);
    _resendTimer?.cancel();
    otherName.dispose();
    otherRelation.dispose();
    otherNote.dispose();
    otp.dispose();
    super.dispose();
  }

  bool get proofDone =>
      proof == 'photo' ? photo : signature != null && !signature!.isEmpty;

  String whoLabel(L10n l) =>
      optionsFor(
            l,
            card:
                ref.read(sessionProvider).taskOrNull(widget.taskId)?.isCard ??
                false,
          )
          .firstWhere(
            (o) => o.$1 == recipient,
            orElse: () => ('', '—', LucideIcons.circle, Dg.elev, Dg.ink),
          )
          .$2;

  String receivedByLabel(L10n l) {
    if (recipient != 'other') return whoLabel(l);
    return '${l.rcvOther}: ${otherName.text.trim()} '
        '(${otherRelation.text.trim()}) · ${otherNote.text.trim()}';
  }

  /// Panel `receiverType` (SELF|RELATIVE|AUTHORIZED|SECRETARY).
  String get receiverType => switch (recipient) {
    'relative' => 'RELATIVE',
    'workplace' || 'security' => 'SECRETARY',
    'authorized' || 'bank' || 'other' => 'AUTHORIZED',
    _ => 'SELF',
  };

  /// Gereksinim yüklendiyse panel kuralı; yoksa eski davranış (OTP istenir).
  bool get otpNeeded {
    final req = ref.read(sessionProvider).visitRequirements(widget.taskId);
    return req?.otpRequired ?? true;
  }

  bool get signatureNeeded =>
      ref
          .read(sessionProvider)
          .visitRequirements(widget.taskId)
          ?.signatureRequired ??
      false;

  /// Panelin teslim fotoğrafı gereksinim kodu (ör. `DELIVERY`).
  String? get photoRequirementCode {
    final req = ref.read(sessionProvider).visitRequirements(widget.taskId);
    if (req != null && req.photos.isNotEmpty) return req.photos.first.code;
    return null;
  }

  bool otpSkipped = false;

  bool get otherComplete =>
      otherName.text.trim().length >= 3 &&
      otherRelation.text.trim().length >= 2 &&
      otherNote.text.trim().length >= 3;

  String cta(L10n l) => step == 1 ? l.completeDelivery : l.continueLabel;

  void _startResendCountdown([int seconds = _resendSeconds]) {
    _resendTimer?.cancel();
    setState(() => resendLeft = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => resendLeft = resendLeft > 0 ? resendLeft - 1 : 0);
      if (resendLeft == 0) t.cancel();
    });
  }

  Future<void> _sendOtp({String channel = 'SMS'}) async {
    final l = context.l10n;
    if (otpBusy || resendLeft > 0 || otpSends >= _maxSends) return;
    setState(() {
      otpBusy = true;
      error = null;
    });
    final s = ref.read(sessionProvider);
    final ok = await s.sendDeliveryOtp(
      widget.taskId,
      receiverType: receiverType,
      channel: channel,
    );
    if (!mounted) return;
    setState(() {
      otpBusy = false;
      if (ok) {
        otpSent = true;
        otpSends += 1;
      } else if (s.deliveryOtpSkippable) {
        // Alıcı telefonu yok: sözleşme gereği OTP adımı atlanır.
        otpSkipped = true;
        error = null;
      } else {
        error = switch (s.deliveryOtpError) {
          'OTP_RATE_LIMITED' => l.otpRateLimited,
          'IVR_UNAVAILABLE' || 'IVR_SEND_FAILED' => l.otpIvrDown,
          _ => l.otpSendFailed,
        };
      }
    });
    if (ok) {
      final at = s.deliveryOtpResendAt;
      final secs = at == null
          ? _resendSeconds
          : at.difference(DateTime.now()).inSeconds.clamp(0, 600);
      _startResendCountdown(secs);
    }
  }

  Future<void> _verifyOtp() async {
    final l = context.l10n;
    if (otpBusy || otp.text.trim().length < 6) return;
    setState(() {
      otpBusy = true;
      error = null;
    });
    final ok = await ref
        .read(sessionProvider)
        .verifyDeliveryOtp(widget.taskId, otp.text.trim());
    if (!mounted) return;
    setState(() {
      otpBusy = false;
      otpVerified = ok;
      if (!ok) error = l.otpMismatchAsk;
    });
    if (ok) _resendTimer?.cancel();
  }

  Future<void> _next() async {
    final l = context.l10n;
    final s = ref.read(sessionProvider);
    setState(() => error = null);
    if (step == 0) {
      if (recipient == null) {
        setState(() => error = l.pickRecipient);
        return;
      }
      if (recipient == 'other' && !otherComplete) {
        setState(() => error = l.otherFieldsNeeded);
        return;
      }
      if ((s.taskOrNull(widget.taskId)?.isCard ?? false) && !s.nfcRead) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const KycScreen()));
        if (!mounted) return;
        if (!ref.read(sessionProvider).nfcRead) {
          setState(() => error = l.identityNeeded);
          return;
        }
      }
      if (otpNeeded && !otpVerified && !otpSkipped) {
        setState(() => error = l.otpNeeded);
        return;
      }
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
          'teslim_alan_ad': recipient == 'other'
              ? otherName.text.trim()
              : s.taskById(widget.taskId).recipient,
          if (recipient == 'other') ...{
            'iliski': otherRelation.text.trim(),
            'aciklama': otherNote.text.trim(),
          },
        },
      );
      setState(() {
        step = 1;
        if (signatureNeeded) proof = 'sign';
      });
      return;
    }
    if (!proofDone) {
      setState(() => error = l.proofNeeded);
      return;
    }
    if (signatureNeeded && proof != 'sign') {
      setState(() => error = l.signatureNeeded);
      return;
    }
    if (proof == 'photo' && photoMediaId != null) {
      s.submitStep(
        taskId: widget.taskId,
        stepKey: 'teslim_fotografi',
        mediaIds: [photoMediaId!],
      );
    }
    if (proof == 'sign') {
      signMediaId ??= await uploadEvidence(
        api: s.panelLoggedIn ? null : s.api,
        panel: s.panelLoggedIn ? s.panel : null,
        // Testte görüntü üretilemez; canlıda gerçek imza gider.
        bytes: inWidgetTest || signature == null
            ? tinyPng()
            : await signature!.toPng(),
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
    if (!mounted) return;
    // Sıra korunur: OTP adımı kanıttan sonra kaydedilir (workflow sırası).
    if (recipient == 'recipient' && s.taskById(widget.taskId).otpRequired) {
      s.submitStep(
        taskId: widget.taskId,
        stepKey: 'otp_dogrula',
        value: {'verificationToken': s.deliveryOtpToken},
      );
    }
    setState(() => submitting = true);
    await s.deliverTask(
      widget.taskId,
      receivedBy: receivedByLabel(l),
      receiverType: receiverType,
      proof: proof == 'sign'
          ? signature?.toProof()
          : const {
              'type': 'DOOR_PHOTO',
              'channel': 'CAMERA_CAPTURE',
              'btk': {'status': 'PENDING_INTEGRATION', 'qualified': false},
            },
    );
    if (!mounted) return;
    // V3 UAT-14: "gönderildi" yalnız sunucu kaydı aldıysa. Kuyrukta
    // bekleyen ya da reddedilen kayıt "cihazda bekliyor" görünür.
    final current = ref.read(sessionProvider);
    final waiting = current.outbox.events.any(
      (e) => e.subjectId == widget.taskId && e.pending,
    );
    setState(() {
      submitting = false;
      confirmed =
          !waiting &&
          current.taskOrNull(widget.taskId)?.status == TaskStatus.delivered;
      done = true;
    });
  }

  Future<void> _goFail() async {
    final failed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReturnScreen(taskId: widget.taskId),
      ),
    );
    if (failed == true && mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final l = context.l10n;
    final task = s.taskOrNull(widget.taskId);
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.stopGone)),
      );
    }
    // Kontrol listesi ya da anket isteyen işler ziyaret akışıyla kapanır.
    if (s.panelLoggedIn && !done) {
      if (!_requirementsReady) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (s.visitRequirements(widget.taskId)?.guided ?? false) {
        return VisitFlowScreen(taskId: widget.taskId);
      }
    }

    if (done) {
      return DeliveryResultScreen(
        success: true,
        task: task,
        who: receivedByLabel(l),
        online: confirmed,
        next: s.nextStop,
        onClose: () => Navigator.popUntil(context, (r) => r.isFirst),
        onNext: () {
          final n = ref.read(sessionProvider).nextStop;
          Navigator.popUntil(context, (r) => r.isFirst);
          if (n == null) return;
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          final warn = context.l10n.startNeedsLocation;
          ref.read(sessionProvider).startTask(n.id).then((ok) {
            if (!ok) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(warn)));
              return;
            }
            nav.push(
              MaterialPageRoute<void>(
                builder: (_) => WizardScreen(taskId: n.id),
              ),
            );
          });
        },
      );
    }

    final card = task.isCard;
    // K05 adımları: Konum (görev başlarken), Teslim Alan, OTP, Kanıt, Sonuç.
    final active = step == 1
        ? 3
        : recipient == null
        ? 1
        : 2;
    return PrivacyGate(
      active: otpSent && !otpVerified,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(l.deliveryTitle),
          leading: step == 1
              ? IconButton(
                  tooltip: l.back,
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: () => setState(() {
                    step = 0;
                    error = null;
                  }),
                )
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  Text(
                    l.deliverySubtitle,
                    textAlign: TextAlign.center,
                    style: Dg.ui(size: 14, color: Dg.ink2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${task.recipient} · ${task.ref}',
                    textAlign: TextAlign.center,
                    style: Dg.ui(size: 13, color: Dg.ink3),
                  ),
                  const SizedBox(height: 16),
                  _Stepper(
                    labels: [
                      l.stepLocation,
                      l.stepRecipient,
                      l.stepOtp,
                      l.stepProof,
                      l.stepResult,
                    ],
                    active: active,
                  ),
                  const SizedBox(height: 20),
                  if (step == 0) ...[
                    if (card) ...[
                      Text(
                        l.cardNoNeighbor,
                        style: Dg.ui(size: 14, color: Dg.ink2, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        DgIcon(LucideIcons.userCheck, size: 20, color: Dg.ink2),
                        const SizedBox(width: 8),
                        Text(
                          l.stepRecipient,
                          style: Dg.ui(size: 16, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, box) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in optionsFor(l, card: card))
                            _RecipientChip(
                              width: ((box.maxWidth - 24) / 4).clamp(
                                72.0,
                                140.0,
                              ),
                              icon: o.$3,
                              label: o.$2,
                              selected: recipient == o.$1,
                              onTap: () => setState(() {
                                recipient = o.$1;
                                error = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                    if (recipient == 'other') ...[
                      const SizedBox(height: 12),
                      for (final (c, hint) in [
                        (otherName, l.otherName),
                        (otherRelation, l.otherRelation),
                        (otherNote, l.otherNote),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextField(
                            controller: c,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(labelText: hint),
                          ),
                        ),
                    ],
                    const SizedBox(height: 18),
                    if (!otpNeeded || otpSkipped)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Dg.surface1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Dg.hairline),
                        ),
                        child: Row(
                          children: [
                            DgIcon(
                              LucideIcons.shieldCheck,
                              size: 22,
                              color: Dg.ok,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                otpSkipped ? l.otpNoPhone : l.otpNotRequired,
                                style: Dg.ui(size: 14, color: Dg.ink2),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _OtpCard(
                        sent: otpSent,
                        verified: otpVerified,
                        busy: otpBusy,
                        resendLeft: resendLeft,
                        sendsLeft: _maxSends - otpSends,
                        controller: otp,
                        error: error != null && otpSent && !otpVerified,
                        onSend: () => _sendOtp(),
                        onSendVoice: () => _sendOtp(channel: 'IVR'),
                        onVerify: _verifyOtp,
                        onChanged: () => setState(() {}),
                        onSupport: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SupportScreen(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Dg.hairline),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DgIcon(LucideIcons.info, size: 18, color: Dg.ink2),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.otpSafety,
                              style: Dg.ui(
                                size: 13,
                                color: Dg.ink2,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const KycScreen(),
                        ),
                      ),
                      child: Text(l.verifyWithId),
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
                          final session = ref.read(sessionProvider);
                          final id = await uploadFileEvidence(
                            api: session.panelLoggedIn ? null : session.api,
                            panel: session.panelLoggedIn ? session.panel : null,
                            path: path,
                            kind: 'photo',
                            taskId: widget.taskId,
                            // Panelde gereksinim kodu (ör. DELIVERY);
                            // kendi API'mizde workflow adımı.
                            stepKey: session.panelLoggedIn
                                ? photoRequirementCode
                                : 'teslim_fotografi',
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
                                fontSize: 14,
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
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ShakeError(
                            trigger: error,
                            child: Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: Dg.ui(
                                size: 15,
                                weight: FontWeight.w600,
                                color: Dg.hi,
                              ),
                            ),
                          ),
                        ),
                      DgButton(
                        label: cta(l),
                        busy: submitting,
                        icon: step == 1 ? LucideIcons.check : null,
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
            child: Text(label, style: TextStyle(fontSize: 14, color: Dg.ink3)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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

/// K05 üstündeki 5 adımlı ilerleme: geçilen adım işaretli, aktif adım halkalı.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.labels, required this.active});

  final List<String> labels;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= active ? Dg.warn : Dg.stroke),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == active
                            ? Dg.warn.withValues(alpha: 0.15)
                            : null,
                        border: Border.all(
                          color: i <= active ? Dg.warn : Dg.stroke,
                          width: i == active ? 2.5 : 1.5,
                        ),
                      ),
                      child: i < active
                          ? DgIcon(LucideIcons.check, size: 16, color: Dg.warn)
                          : Text(
                              '${i + 1}',
                              style: Dg.ui(
                                size: 13,
                                weight: FontWeight.w700,
                                color: i == active ? Dg.ink : Dg.ink2,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == labels.length - 1
                            ? Colors.transparent
                            : (i < active ? Dg.warn : Dg.stroke),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: Dg.ui(
                      size: 12,
                      weight: i == active ? FontWeight.w700 : FontWeight.w500,
                      color: i == active ? Dg.ink : Dg.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({
    required this.width,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: width,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Dg.warn.withValues(alpha: 0.14) : Dg.surface1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Dg.warn : Dg.hairline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DgIcon(icon, size: 22, color: selected ? Dg.warn : Dg.ink2),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Dg.ui(size: 13, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({
    required this.sent,
    required this.verified,
    required this.busy,
    required this.resendLeft,
    required this.sendsLeft,
    required this.controller,
    required this.error,
    required this.onSend,
    required this.onSendVoice,
    required this.onVerify,
    required this.onChanged,
    required this.onSupport,
  });

  final bool sent;
  final bool verified;
  final bool busy;
  final int resendLeft;
  final int sendsLeft;
  final TextEditingController controller;
  final bool error;
  final VoidCallback onSend;
  final VoidCallback onSendVoice;
  final VoidCallback onVerify;
  final VoidCallback onChanged;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String mmss(int s) =>
        '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Dg.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: verified ? Dg.ok : Dg.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DgIcon(
                verified ? LucideIcons.shieldCheck : LucideIcons.shield,
                size: 28,
                color: verified ? Dg.ok : Dg.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verified ? l.otpVerified : l.otpTitle,
                      style: Dg.ui(
                        size: 16,
                        weight: FontWeight.w700,
                        color: verified ? Dg.ok : Dg.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.otpBody,
                      style: Dg.ui(size: 13, color: Dg.ink2, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!verified) ...[
            const SizedBox(height: 14),
            if (!sent)
              DgButton(
                label: l.otpSend,
                icon: LucideIcons.send,
                tone: DgButtonTone.secondary,
                busy: busy,
                onPressed: onSend,
              )
            else ...[
              OtpPin(
                controller: controller,
                error: error,
                onCompleted: (_) => onVerify(),
              ),
              const SizedBox(height: 10),
              if (sendsLeft <= 0 && resendLeft == 0)
                TextButton.icon(
                  onPressed: onSupport,
                  icon: const Icon(LucideIcons.headset, size: 18),
                  label: Text('${l.otpLimit} ${l.callCenterSupport}'),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: resendLeft > 0 || busy ? null : onSend,
                      icon: const Icon(LucideIcons.rotateCcw, size: 18),
                      label: Text(l.otpResend),
                    ),
                    if (resendLeft > 0)
                      Text(
                        mmss(resendLeft),
                        style: Dg.ui(size: 14, color: Dg.ink2),
                      ),
                  ],
                ),
              if (resendLeft == 0 && sendsLeft > 0)
                TextButton.icon(
                  onPressed: busy ? null : onSendVoice,
                  icon: const Icon(LucideIcons.phoneCall, size: 18),
                  label: Text(l.otpByVoice),
                ),
              const SizedBox(height: 6),
              DgButton(
                label: l.otpVerify,
                icon: LucideIcons.shieldCheck,
                tone: DgButtonTone.secondary,
                busy: busy,
                onPressed: controller.text.trim().length == 6 ? onVerify : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
