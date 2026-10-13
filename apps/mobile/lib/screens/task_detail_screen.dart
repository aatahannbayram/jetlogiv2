import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../geo.dart';
import '../l10n.dart';
import '../launchers.dart';
import '../motion.dart';
import '../models.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'report_screen.dart';
import 'return_screen.dart';
import 'wizard_screen.dart';

/// Canvas'ın "1d Görev detayı" tasarımı — tam ekran harita + kaydırmalı
/// alt sheet. Kapıda ödeme yerine Zimmet/Teslim penceresi/Teslim kodu
/// ikonlu bilgi kartları (bkz. plan Faz E).
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(sessionProvider);
      unawaited(s.ensureDayRoute());
      if (!s.routeLoading) unawaited(s.loadRoute());
      // Ziyaret işi mi (kontrol listesi / anket) bilmek için.
      unawaited(s.loadTaskRequirements(widget.taskId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final t = session.taskOrNull(widget.taskId);
    final guided = session.visitRequirements(widget.taskId)?.guided ?? false;
    if (t == null) {
      return Scaffold(
        backgroundColor: Dg.night,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _SheetBack(onTap: () => Navigator.of(context).pop()),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    l.stopGone,
                    style: Dg.ui(size: 15, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final done = t.status == TaskStatus.delivered;
    final canAct = !t.isClosed;
    final self = LatLng(session.selfLat, session.selfLng);
    final dest = LatLng(t.lat, t.lng);
    final slice = t.hasCoordinates ? session.roadToTask(t.id) : null;
    final meters = slice?.meters ?? haversineMeters(self, dest).round();
    final minutes = slice != null
        ? slice.minutes
        : (t.etaMinutes ?? (meters / 450).clamp(1, 40).round());

    Future<void> start() async {
      final ok = await ref.read(sessionProvider).startTask(t.id);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.startNeedsLocation)));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => WizardScreen(taskId: t.id)),
      );
    }

    return Scaffold(
      // Alt kartla aynı renk: kart yukarı bindiği için altta kalan pay görünmez.
      backgroundColor: Dg.surface,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MapStrip(
                  height: double.infinity,
                  rounded: false,
                  interactive: true,
                  points: t.hasCoordinates ? [dest] : [self],
                  roadPoints: slice != null && slice.points.length > 1
                      ? slice.points
                      : null,
                  polylinePrecision: slice?.precision ?? 6,
                  estimated: slice?.estimated ?? true,
                  couriers: session.visibleFleet.where((c) => c.self).toList(),
                  fitTo: keepNearStops(
                    t.hasCoordinates ? [self, dest] : [self],
                    t.hasCoordinates ? [dest] : const [],
                  ),
                  showBadge: false,
                  // İğnenin üstünde varış süresi; yürüme mesafesinde uzaklık.
                  pinLabel: !t.hasCoordinates
                      ? null
                      : slice != null && slice.walking
                      ? l.travelLabel(meters, null)
                      : '$minutes ${l.minutesShort}',
                ),
                // `Positioned` şart: bu Stack `StackFit.expand` kullanıyor,
                // konumlanmamış (non-positioned) bir çocuk (SafeArea gibi)
                // Stack'in TAMAMI kadar gerilir. O zaman içindeki Row da
                // gerilen kutunun tamamını kaplar ve varsayılan
                // `crossAxisAlignment: center` yüzünden geri/mesafe/Kuryeler
                // şeridi ekranın üstü yerine ortasına düşer. `Positioned` bu
                // şeridi sadece kendi doğal yüksekliğine sabitler.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Appear(
                        slide: -0.15,
                        child: Row(
                          children: [
                            _SheetBack(
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: _RouteChip(
                                text: slice != null && !slice.estimated
                                    ? l.travelLabel(
                                        meters,
                                        minutes,
                                        walking: slice.walking,
                                      )
                                    : '${l.travelLabel(meters, minutes)}  ·  ${l.approxRoute}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sabit yükseklikli bir Column, uzun içerikte (adres iki satır +
          // zimmet + pencere + 3 ikon + kaydırma çubuğu + iade linki) haritayı
          // ekranın küçük bir kısmına sıkıştırıyordu — üstteki geri/mesafe/
          // Kuryeler şeridi o zaman "ortada" gibi görünüyordu. Yükseklik payı
          // artık ekranın en fazla %48'i; taşan içerik kaydırılır.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            // Kart haritanın üstüne biner: yuvarlak köşelerin arkasında
            // boşluk değil harita görünür. Tutamak sabittir, içerik onun
            // altında kayar; kaydırınca başlık kesilmiş gibi durmaz.
            child: Transform.translate(
              offset: const Offset(0, -_sheetOverlap),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Dg.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Dg.radiusPill),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Appear(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(top: 10, bottom: 6),
                          decoration: BoxDecoration(
                            color: Dg.ink3.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              Dg.pagePad,
                              10,
                              Dg.pagePad,
                              22 - _sheetOverlap,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Mono(
                                        taskRefLine(
                                          t,
                                          visit: session.visitNumber(t.id),
                                        ),
                                        color: Dg.ink3,
                                      ),
                                    ),
                                    StatusChip(
                                      label: taskChipLabel(t, l),
                                      tone: taskChipTone(t),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Hero(
                                  tag: 'recipient-${t.id}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Row(
                                      children: [
                                        InitialsAvatar(
                                          name: t.recipient,
                                          photoUrl: t.personPhoto,
                                          size: 40,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Display(t.recipient, size: 22),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Dg.ink2,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                                if (t.merchantName != null &&
                                    t.merchantName!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Dg.violetBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      t.merchantName!,
                                      style: Dg.ui(
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: Dg.violet,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                const DgDivider(),
                                _InfoCard(
                                  icon: LucideIcons.layers,
                                  label: l.custody,
                                  value: t.custodyCount == null
                                      ? '—'
                                      : l.itemsWithRef(
                                          t.custodyCount!,
                                          t.custodyRef,
                                        ),
                                ),
                                const DgDivider(),
                                _InfoCard(
                                  icon: LucideIcons.clock,
                                  label: l.deliveryWindowLeft,
                                  value: t.slaMinutesLeft == null
                                      ? t.window
                                      : t.slaMinutesLeft! < 0
                                      ? l.minutesLate(-t.slaMinutesLeft!)
                                      : l.slaLeft(t.slaLabel),
                                ),
                                if (t.otpRequired) ...[
                                  const DgDivider(),
                                  _InfoCard(
                                    icon: LucideIcons.key,
                                    label: l.deliveryCode,
                                    value: l.askRecipient,
                                    dot: true,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    SquareAction(
                                      icon: LucideIcons.phone,
                                      label: l.callShort,
                                      color: Dg.ok,
                                      onTap: () => session.callTask(context, t),
                                    ),
                                    const SizedBox(width: 10),
                                    SquareAction(
                                      icon: LucideIcons.navigation,
                                      label: l.routeShort,
                                      onTap: () => openDirections(context, t),
                                    ),
                                    // Fotoğraf burada çekilmez: teslim sırasında
                                    // kanıt olarak alınır.
                                    if (session.panelLoggedIn) ...[
                                      const SizedBox(width: 10),
                                      SquareAction(
                                        icon: LucideIcons.fileSignature,
                                        label: l.reportTitle,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                ReportScreen(taskId: t.id),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Asıl eylemler kaymaz: kurye kaydırmadan her zaman görür.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Dg.pagePad,
                            10,
                            Dg.pagePad,
                            12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (done)
                                Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Dg.loBg,
                                        borderRadius: BorderRadius.circular(
                                          Dg.radiusPill,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            LucideIcons.circleCheck,
                                            size: 20,
                                            color: Dg.lo,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            l.deliveredOk,
                                            style: Dg.ui(
                                              size: 16,
                                              weight: FontWeight.w700,
                                              color: Dg.lo,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .scale(
                                      begin: const Offset(0.96, 0.96),
                                      duration: 220.ms,
                                      curve: Curves.easeOutBack,
                                    )
                                    .fadeIn(duration: 180.ms)
                              else if (canAct)
                                SlideToAct(
                                  label: guided
                                      ? l.visitSlide
                                      : l.slideToDeliver,
                                  onConfirm: start,
                                ),
                              if (canAct) ...[
                                const SizedBox(height: 10),
                                // Kuryenin gözünden kaçmasın: tam genişlikte kırmızı.
                                DgButton(
                                  label: guided
                                      ? l.visitCouldNot
                                      : l.couldNotDeliverShort,
                                  icon: LucideIcons.circleX,
                                  tone: DgButtonTone.danger,
                                  onPressed: () async {
                                    final failed = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute<bool>(
                                            builder: (_) =>
                                                ReturnScreen(taskId: t.id),
                                          ),
                                        );
                                    if (failed == true && context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt kartın haritanın üstüne bindiği pay.
const _sheetOverlap = 22.0;

/// Canvas'ın "Zimmet/Teslim penceresi/Teslim kodu" bilgi satırları —
/// ikon + etiket solda, değer sağda; [dot] gerektiğinde değerin önüne
/// bekleyen-durum noktası ekler (teslim kodu henüz alınmadıysa).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Dg.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: Dg.ui(size: 14, color: Dg.ink3)),
          ),
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: Dg.sand, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Dg.ui(size: 14, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mesafe/süre rozeti — dolu gradyan dolgu, ince mor çerçeve YOK: kısmen
/// saydam koyu zemin + tek renkli kenarlık "hesaplanmamış/yükleniyor" gibi
/// okunuyordu. Dolu dolgu + gölge "kesin, hesaplanmış" bir değeri iletiyor.
class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Dg.neon,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DgIcon(
            LucideIcons.navigation,
            size: 15,
            color: Dg.onNeon,
            weight: 600,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Dg.ui(size: 15, weight: FontWeight.w700, color: Dg.onNeon),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetBack extends StatelessWidget {
  const _SheetBack({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Dg.surface,
          elevation: 3,
          shadowColor: const Color(0x33000000),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: DgIcon(LucideIcons.arrowLeft, size: 20, color: Dg.ink),
            ),
          ),
        ),
      ),
    );
  }
}
