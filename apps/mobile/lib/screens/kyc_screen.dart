import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../log.dart';
import '../motion.dart';
import '../scan.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  int _doc = 0;
  String? _photoPath;
  bool _scanning = false;
  late final doc = TextEditingController(
    text: ref.read(sessionProvider).mrzDoc,
  );
  late final dob = TextEditingController(
    text: ref.read(sessionProvider).mrzDob,
  );

  bool get _hasPhoto => _photoPath != null;

  @override
  void dispose() {
    doc.dispose();
    dob.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final path = await capturePhoto();
    if (!mounted || path == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _photoPath = path);
    DgLog.i(LogLayer.session, 'kyc photo ${_doc + 1}');
  }

  Future<void> _readChip() async {
    if (_scanning || ref.read(sessionProvider).nfcRead) return;
    setState(() => _scanning = true);
    HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    ref.read(sessionProvider).readNfc();
    DgLog.i(LogLayer.session, 'kyc nfc ${_doc + 1}');
    setState(() => _scanning = false);
    HapticFeedback.mediumImpact();
  }

  Future<void> _cta() async {
    final s = ref.read(sessionProvider);
    if (s.nfcRead) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    if (!_hasPhoto) {
      await _takePhoto();
      return;
    }
    await _readChip();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.kycTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Dg.pagePad, 8, Dg.pagePad, 20),
              children: [
                Appear(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.kycLead,
                        style: Dg.ui(size: 15, color: Dg.ink2, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StepChip(
                              n: '1',
                              label: l.kycDocsKicker,
                              on: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StepChip(
                              n: '2',
                              label: l.kycPhotoKicker,
                              on: _hasPhoto,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StepChip(
                              n: '3',
                              label: l.kycChipKicker,
                              on: s.nfcRead,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(l.kycDocsKicker, style: Dg.kicker(color: Dg.ink2)),
                const SizedBox(height: 8),
                DgCard(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (i, d) in s.kycDocs.indexed)
                        _DocChip(
                          label: l.kycDocAt(i),
                          icon: d.icon,
                          selected: _doc == i,
                          onTap: () => setState(() => _doc = i),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(l.kycPhotoKicker, style: Dg.kicker(color: Dg.ink2)),
                const SizedBox(height: 8),
                Appear(
                  delay: const Duration(milliseconds: 40),
                  child: Pressable(
                    onTap: _takePhoto,
                    child: _PhotoSlot(
                      path: _photoPath,
                      emptyLabel: l.kycPhotoHint,
                      takenLabel: l.kycPhotoTaken,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(l.kycChipKicker, style: Dg.kicker(color: Dg.ink2)),
                const SizedBox(height: 8),
                Appear(
                  delay: const Duration(milliseconds: 80),
                  child: Pressable(
                    onTap: _hasPhoto && !s.nfcRead ? _readChip : () {},
                    child: _NfcCard(
                      scanning: _scanning,
                      read: s.nfcRead,
                      title: s.nfcRead
                          ? l.chipRead
                          : _scanning
                          ? l.kycScanning
                          : l.nfcReady,
                      subtitle: s.nfcRead
                          ? l.mrzVerified
                          : _scanning
                          ? l.holdIdBack
                          : l.holdIdBack,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(l.kycMrzKicker, style: Dg.kicker(color: Dg.ink2)),
                const SizedBox(height: 8),
                DgCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    children: [
                      _MrzField(
                        label: l.docNo,
                        controller: doc,
                        onChanged: s.setMrzDoc,
                      ),
                      const SizedBox(height: 14),
                      _MrzField(
                        label: l.dobYymmdd,
                        controller: dob,
                        onChanged: s.setMrzDob,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Dg.pagePad,
                8,
                Dg.pagePad,
                12,
              ),
              child: DgButton(
                label: s.nfcRead
                    ? l.done
                    : !_hasPhoto
                    ? l.takePhoto
                    : l.nfcRead,
                icon: s.nfcRead
                    ? LucideIcons.badgeCheck
                    : !_hasPhoto
                    ? LucideIcons.camera
                    : LucideIcons.nfc,
                busy: _scanning,
                onPressed: _scanning ? null : _cta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.n, required this.label, required this.on});

  final String n;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: on ? Dg.ink : Dg.elev,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            n,
            style: Dg.ui(
              size: 12,
              weight: FontWeight.w700,
              color: on ? (Dg.dark ? Dg.night : Colors.white) : Dg.ink2,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Dg.ui(
                size: 11,
                weight: FontWeight.w700,
                color: on ? (Dg.dark ? Dg.night : Colors.white) : Dg.ink2,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocChip extends StatelessWidget {
  const _DocChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onInk = Dg.dark ? Dg.night : Colors.white;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected ? Dg.ink : Dg.elev,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DgIcon(icon, size: 16, color: selected ? onInk : Dg.ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: Dg.ui(
                size: 14,
                weight: FontWeight.w600,
                color: selected ? onInk : Dg.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.path,
    required this.emptyLabel,
    required this.takenLabel,
  });

  final String? path;
  final String emptyLabel;
  final String takenLabel;

  bool get _fileReady {
    final p = path;
    if (p == null || p.startsWith('test://')) return false;
    return File(p).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final taken = path != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 148,
      width: double.infinity,
      decoration: BoxDecoration(
        color: taken ? Dg.greenBg : Dg.surface,
        borderRadius: BorderRadius.circular(Dg.radiusHero),
        border: Border.all(color: taken ? Dg.green.withValues(alpha: 0.35) : Dg.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_fileReady)
            Image.file(File(path!), fit: BoxFit.cover)
          else
            ColoredBox(color: taken ? Dg.greenBg : Dg.elev),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DgIcon(
                  taken ? LucideIcons.circleCheck : LucideIcons.camera,
                  size: 28,
                  color: taken ? Dg.ok : Dg.ink,
                  weight: 600,
                ),
                const SizedBox(height: 8),
                Text(
                  taken ? takenLabel : emptyLabel,
                  style: Dg.ui(
                    size: 15,
                    weight: FontWeight.w600,
                    color: taken ? Dg.green : Dg.ink,
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

class _NfcCard extends StatelessWidget {
  const _NfcCard({
    required this.scanning,
    required this.read,
    required this.title,
    required this.subtitle,
  });

  final bool scanning;
  final bool read;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DgCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: read ? Dg.greenBg : Dg.elev,
              shape: BoxShape.circle,
            ),
            child: scanning
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Dg.ink,
                    ),
                  )
                : DgIcon(
                    read ? LucideIcons.circleCheck : LucideIcons.nfc,
                    size: 24,
                    color: read ? Dg.ok : Dg.ink,
                    weight: 600,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Dg.ui(size: 17, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Dg.ui(size: 14, color: Dg.ink2, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MrzField extends StatelessWidget {
  const _MrzField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Dg.kicker(color: Dg.ink2)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Dg.rowMin),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Dg.elev,
              borderRadius: BorderRadius.circular(Dg.radiusHero),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontFamily: Dg.mono,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    filled: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
