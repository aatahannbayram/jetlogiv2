import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';
import '../session.dart';
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
  String? relationCode;
  String proof = 'photo';
  bool photo = false;
  final signature = <Offset?>[];
  bool otpSent = false;
  final otp = TextEditingController();
  String? error;
  bool done = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(sessionProvider);
      if (!s.usesJetdijiCourier) return;
      unawaited(s.loadTaskRequirements(widget.taskId));
    });
  }

  // Getter, not `static const` — the tint/ink pair (Dg.violetBg, ...) reads
  // Dg.dark at call time, so this must re-evaluate on every access instead
  // of being frozen at first use (otherwise it'd go stale after a
  // koyu/açık tema toggle).
  static List<(String, String, IconData, Color, Color)> get options => [
    ('recipient', 'Alıcının kendisi', LucideIcons.user, Dg.violetBg, Dg.violet),
    ('relative', 'Aile bireyi', LucideIcons.users, Dg.blueBg, Dg.blue),
    ('neighbor', 'Komşu', LucideIcons.doorOpen, Dg.amberBg, Dg.amber),
    (
      'workplace',
      'İş yeri / resepsiyon',
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

  bool get proofDone {
    final s = ref.read(sessionProvider);
    if (!s.usesJetdijiCourier) {
      return proof == 'photo' ? photo : signature.isNotEmpty;
    }
    final photoOk = !showPhoto || photo;
    final signOk = !showSign || signature.isNotEmpty;
    return photoOk && signOk;
  }

  bool get showPhoto {
    final s = ref.read(sessionProvider);
    if (!s.usesJetdijiCourier) return true;
    final req = s.requirementsByTask[widget.taskId];
    if (req == null) return true;
    return req.photos.isNotEmpty;
  }

  bool get showSign {
    final s = ref.read(sessionProvider);
    if (!s.usesJetdijiCourier) return true;
    final req = s.requirementsByTask[widget.taskId];
    if (req == null) return true;
    return req.signatureRequired;
  }

  List<String> get steps {
    final s = ref.read(sessionProvider);
    if (!s.usesJetdijiCourier) return const ['who', 'proof', 'otp'];
    final req = s.requirementsByTask[widget.taskId];
    final next = <String>['who'];
    final photos = req == null || req.photos.isNotEmpty;
    final sign = req == null || req.signatureRequired;
    if (photos || sign) next.add('proof');
    if (req?.formRequired == true) next.add('form');
    if (req == null || req.otpRequired) next.add('otp');
    return next;
  }

  String get current => steps[step.clamp(0, steps.length - 1)];

  String get whoLabel => options
      .firstWhere(
        (o) => o.$1 == recipient,
        orElse: () => ('', '—', LucideIcons.circle, Dg.elev, Dg.ink),
      )
      .$2;

  String get cta {
    if (current == 'proof' && proofDone) return 'Kullan';
    if (current == 'otp') {
      return otpSent ? 'Doğrula ve teslim et' : 'Kodu gönder';
    }
    if (current == steps.last && current != 'otp') return 'Teslim et';
    return 'Devam';
  }

  Future<void> _next() async {
    if (busy) return;
    setState(() => error = null);
    final session = ref.read(sessionProvider);
    if (current == 'who') {
      if (recipient == null) {
        setState(() => error = 'Teslim alan kişiyi seçin.');
        return;
      }
      if (session.usesJetdijiCourier &&
          session.deliveryReasons != null &&
          session.deliveryReasons!.delivered.isNotEmpty &&
          (relationCode == null || relationCode!.isEmpty)) {
        setState(() => error = 'Yakınlık kodunu seçin.');
        return;
      }
    }
    if (current == 'proof' && !proofDone) {
      setState(() => error = 'Kapı fotoğrafı veya alıcı imzası gerekli.');
      return;
    }
    if (current == 'form') {
      setState(() => busy = true);
      final ok = await session.submitDeliveryForm(widget.taskId);
      if (!mounted) return;
      setState(() => busy = false);
      if (!ok) {
        setState(() => error = session.lastJetdijiError ?? 'Form kaydedilemedi.');
        return;
      }
    }
    if (current == 'otp') {
      final receiver = jetdijiReceiverType(recipient) ?? 'SELF';
      if (!otpSent) {
        if (session.usesJetdijiCourier) {
          setState(() => busy = true);
          final dev = await session.sendDeliveryOtp(
            widget.taskId,
            receiverType: receiver,
          );
          if (!mounted) return;
          setState(() => busy = false);
          if (session.otpChallengeByTask[widget.taskId] == null) {
            setState(
              () => error = session.lastJetdijiError ?? 'Kod gönderilemedi.',
            );
            return;
          }
          setState(() {
            otpSent = true;
            if (dev != null) error = null;
          });
          return;
        }
        setState(() => otpSent = true);
        return;
      }
      final ok = session.usesJetdijiCourier
          ? await session.verifyDeliveryOtpAsync(otp.text.trim(), taskId: widget.taskId)
          : session.verifyDeliveryOtp(otp.text.trim());
      if (!ok) {
        setState(() => error = 'Kod eşleşmedi. Alıcıya yeniden sorun.');
        return;
      }
    }
    if (step < steps.length - 1 && current != 'otp') {
      setState(() => step += 1);
      return;
    }
    if (current != 'otp' && step < steps.length - 1) return;
    setState(() => busy = true);
    final delivered = await session.deliverTask(
      widget.taskId,
      receivedBy: whoLabel,
      receiverType: session.usesJetdijiCourier
          ? jetdijiReceiverType(recipient)
          : null,
      receivedRelationCode: relationCode,
      otpEvidenceId: session.otpEvidenceByTask[widget.taskId],
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (!delivered) {
      setState(
        () => error = session.lastJetdijiError ?? 'Teslim kaydedilemedi.',
      );
      return;
    }
    setState(() => done = true);
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

    if (done) {
      return DeliveryResultScreen(
        success: true,
        task: task,
        who: whoLabel,
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

    final titles = {
      'who': 'Teslim alan',
      'proof': 'Kanıt',
      'form': 'Form',
      'otp': 'Teslim kodu',
    };
    final flow = steps;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titles[current] ?? 'Teslim'),
            Text(
              'Adım ${step + 1}/${flow.length}  ·  ${task.ref}',
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
                for (var i = 0; i < flow.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? Dg.primaryGradientStart : Dg.elev,
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
                if (current == 'who') ...[
                  for (final (i, o) in options.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: StaggerIn(
                        index: i,
                        child: Material(
                          color: recipient == o.$1 ? Dg.accentSoft : Dg.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Dg.radius),
                            side: BorderSide(
                              color: recipient == o.$1 ? Dg.accent : Dg.rule,
                              width: recipient == o.$1 ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => setState(() => recipient = o.$1),
                            borderRadius: BorderRadius.circular(Dg.radius),
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
                                  Icon(
                                    recipient == o.$1
                                        ? LucideIcons.circleCheck
                                        : LucideIcons.circle,
                                    color: recipient == o.$1
                                        ? Dg.accent
                                        : Dg.ink3,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (s.usesJetdijiCourier &&
                      (s.deliveryReasons?.delivered.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Yakınlık kodu',
                      style: TextStyle(color: Dg.ink2, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final reason in s.deliveryReasons!.delivered)
                          ChoiceChip(
                            label: Text(reason.name),
                            selected: relationCode == reason.code,
                            onSelected: (_) =>
                                setState(() => relationCode = reason.code),
                          ),
                      ],
                    ),
                  ],
                  if (s.calledTaskIds.contains(task.id))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Arama kaydı var.',
                        style: TextStyle(color: Dg.ink2),
                      ),
                    ),
                ],
                if (current == 'proof') ...[
                  if (showPhoto && showSign)
                    SegmentedTabs(
                    labels: const ['Fotoğraf', 'İmza'],
                    index: proof == 'photo' ? 0 : 1,
                    onChanged: (i) =>
                        setState(() => proof = i == 0 ? 'photo' : 'sign'),
                  ),
                  const SizedBox(height: 16),
                  if (showPhoto && (proof == 'photo' || !showSign)) ...[
                    Viewfinder(
                      captured: photo,
                      onCapture: () => setState(() => photo = true),
                    ),
                    if (photo)
                      TextButton(
                        onPressed: () => setState(() => photo = false),
                        child: const Text('Tekrar çek'),
                      ),
                  ] else if (showSign) ...[
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
                            'Yukarıda belirtilen gönderiyi eksiksiz ve hasarsız teslim aldığımı beyan ederim.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Dg.ink2,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const DgDivider(),
                          const SizedBox(height: 10),
                          _declarationRow('Gönderi no', task.ref),
                          _declarationRow('Alıcı', task.recipient),
                          _declarationRow('Tarih', _now()),
                        ],
                      ),
                    ),
                    _SignaturePad(
                      points: signature,
                      onChanged: (pts) => setState(() {
                        signature
                          ..clear()
                          ..addAll(pts);
                      }),
                    ),
                    if (signature.isNotEmpty) ...[
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
                              'İmza kaydı · Sahada imzalandı',
                              style: Dg.ui(size: 13, color: Dg.ink2),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(signature.clear),
                            child: const Text('Temizle'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
                if (current == 'form')
                  Text(
                    'Zorunlu form bu adımda kaydedilir.',
                    style: TextStyle(color: Dg.ink2, height: 1.4),
                  ),
                if (current == 'otp') ...[
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
                          s.usesJetdijiCourier
                              ? 'Alıcıdan 6 haneli kodu isteyin'
                              : 'Alıcıdan 4 haneli kodu isteyin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          otpSent
                              ? 'Kod, alıcının telefonuna SMS ile gönderildi. Kodu görmeden teslim etme.'
                              : 'Alıcının telefonuna tek kullanımlık bir kod göndereceğiz.',
                          style: const TextStyle(
                            color: Color(0xFF9A9E90),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        if (s.otpDevCodeByTask[task.id] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Geliştirme kodu: ${s.otpDevCodeByTask[task.id]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                              'Kod gelmedi mi? Yeniden gönder',
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
                              'Kod alınamıyor · kimlik ile doğrula',
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
                    FilledButton(
                      onPressed: busy ? null : () => unawaited(_next()),
                      child: Text(busy ? 'Kaydediliyor' : cta),
                    ),
                    TextButton(
                      onPressed: _goFail,
                      child: Text(
                        'Teslim edemedim',
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

class _SignaturePad extends StatefulWidget {
  const _SignaturePad({required this.points, required this.onChanged});

  final List<Offset?> points;
  final ValueChanged<List<Offset?>> onChanged;

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  late final _pts = List<Offset?>.from(widget.points);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 342 / 274,
      child: GestureDetector(
        onPanUpdate: (d) {
          final box = context.findRenderObject() as RenderBox;
          setState(() => _pts.add(box.globalToLocal(d.globalPosition)));
          widget.onChanged(_pts);
        },
        onPanEnd: (_) {
          setState(() => _pts.add(null));
          widget.onChanged(_pts);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Dg.surface,
            borderRadius: BorderRadius.circular(Dg.radius),
            border: Border.all(color: Dg.rule),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_pts.isEmpty)
                Center(
                  child: Text(
                    'Parmağınla imzala',
                    style: Dg.ui(size: 14, color: Dg.ink3),
                  ),
                ),
              CustomPaint(painter: _SignaturePainter(_pts)),
              Positioned(
                left: 20,
                right: 20,
                bottom: 34,
                child: const DgDivider(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Dg.ink
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) canvas.drawLine(a, b, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) =>
      oldDelegate.points != points;
}
