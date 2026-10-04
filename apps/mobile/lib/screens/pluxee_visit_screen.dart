import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pluxee/capture.dart';
import '../pluxee/catalog.dart';
import '../pluxee/draft.dart';
import '../pluxee/submit.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Kind {
  applied,
  existing,
  echo,
  other,
  visual,
  note,
  reason,
  detail,
  photo,
  review,
}

class _Step {
  const _Step(this.kind, [this.slot]);

  final _Kind kind;
  final String? slot;
}

class PluxeeVisitScreen extends ConsumerStatefulWidget {
  const PluxeeVisitScreen({
    super.key,
    required this.taskId,
    this.capture,
    this.locate,
    this.openSettings,
    this.catalog,
  });

  final String taskId;
  final Future<PluxeePhoto?> Function(String slot)? capture;
  final Future<PluxeeFix> Function()? locate;
  final Future<void> Function()? openSettings;
  final PluxeeCatalog? catalog;

  @override
  ConsumerState<PluxeeVisitScreen> createState() => _PluxeeVisitScreenState();
}

class _PluxeeVisitScreenState extends ConsumerState<PluxeeVisitScreen> {
  late final PluxeeDraft draft = PluxeeDraft(taskId: widget.taskId);
  late final noteController = TextEditingController();
  PluxeeCatalog? catalog;
  int index = 0;
  String? error;
  bool busy = false;
  bool ready = false;
  PluxeeSubmitResult? outcome;

  List<_Step> get steps {
    final next = <_Step>[
      const _Step(_Kind.applied),
      const _Step(_Kind.existing),
      const _Step(_Kind.echo),
      const _Step(_Kind.other),
      const _Step(_Kind.visual),
      const _Step(_Kind.note),
    ];
    if (draft.stickerApplied == true) {
      for (final slot in PluxeeSlots.yesBranch) {
        next.add(_Step(_Kind.photo, slot));
      }
      next.add(const _Step(_Kind.review));
    } else if (draft.stickerApplied == false) {
      next
        ..add(const _Step(_Kind.reason))
        ..add(const _Step(_Kind.detail));
      for (final slot in PluxeeSlots.noBranch) {
        next.add(_Step(_Kind.photo, slot));
      }
      next.add(const _Step(_Kind.review));
    }
    return next;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final stored = await ref.read(sessionProvider).pluxee?.load(widget.taskId);
    final loaded = widget.catalog ?? await PluxeeCatalog.load();
    if (!mounted) return;
    setState(() {
      if (stored != null) _copy(stored);
      catalog = loaded;
      noteController.text = draft.note;
      ready = true;
      _clamp();
    });
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  void _copy(PluxeeDraft stored) {
    draft
      ..stickerApplied = stored.stickerApplied
      ..existingSticker = stored.existingSticker
      ..otherMealCard = stored.otherMealCard
      ..visualDelivered = stored.visualDelivered
      ..note = stored.note
      ..reasonKey = stored.reasonKey
      ..detailKey = stored.detailKey
      ..latitude = stored.latitude
      ..longitude = stored.longitude
      ..locationCapturedAt = stored.locationCapturedAt
      ..cameraDenied = stored.cameraDenied
      ..submitted = stored.submitted
      ..awaitingForm = stored.awaitingForm
      ..heldForOps = stored.heldForOps
      ..formIdempotencyKey = stored.formIdempotencyKey
      ..formFingerprint = stored.formFingerprint;
    draft.photos
      ..clear()
      ..addAll(stored.photos);
  }

  Future<void> _save() =>
      ref.read(sessionProvider).pluxee?.save(draft) ?? Future.value();

  void _clamp() {
    if (index >= steps.length) index = steps.length - 1;
    if (index < 0) index = 0;
  }

  String? _block() {
    final step = steps[index];
    switch (step.kind) {
      case _Kind.applied:
        if (draft.stickerApplied == null) return 'Sticker uygulandı mı, seçin.';
      case _Kind.existing:
        if (draft.existingSticker == null) {
          return 'Pluxee sticker var mı, seçin.';
        }
      case _Kind.other:
        if (draft.otherMealCard == null) {
          return 'Başka yemek kartı var mı, seçin.';
        }
      case _Kind.visual:
        if (draft.visualDelivered == null) return 'Görsel teslimi zorunlu.';
      case _Kind.reason:
        if (draft.reasonKey == null) return 'İptal sebebi seçin.';
      case _Kind.detail:
        if (draft.detailKey == null || draft.detailKey!.isEmpty) {
          return 'İptal açıklaması seçin.';
        }
      case _Kind.photo:
        final photo = draft.photos[step.slot];
        if (photo == null || !photo.used) {
          return 'Fotoğrafı kullanmadan devam edilmez.';
        }
      case _Kind.echo:
      case _Kind.note:
      case _Kind.review:
        break;
    }
    return null;
  }

  Future<void> _forward() async {
    final problem = _block();
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      index += 1;
      _clamp();
      error = null;
    });
    await _save();
    if (steps[index].kind == _Kind.review) unawaited(_locate());
  }

  void _back() {
    if (index == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      index -= 1;
      error = null;
    });
  }

  Future<void> _shoot() async {
    final slot = steps[index].slot;
    if (slot == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final photo = await (widget.capture ?? capturePluxeePhoto)(slot);
      if (!mounted) return;
      if (photo == null) {
        setState(() => busy = false);
        return;
      }
      final problem = draft.assignPhoto(photo);
      setState(() {
        busy = false;
        error = problem;
        draft.cameraDenied = false;
      });
      if (problem == null) await _save();
    } on PluxeeCameraDenied {
      if (!mounted) return;
      draft.cameraDenied = true;
      setState(() {
        busy = false;
        error = 'Kamera izni yok. Ayarlardan izin verin.';
      });
      await _save();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        busy = false;
        this.error = 'Fotoğraf çekilemedi.';
      });
    }
  }

  Future<void> _locate() async {
    setState(() => busy = true);
    try {
      final fix = await (widget.locate ?? capturePluxeeFix)();
      if (!mounted) return;
      if (fix.denied) {
        setState(() {
          busy = false;
          error = 'Konum izni yok. Ayarlardan izin verin.';
        });
        return;
      }
      draft.setLocation(
        latitude: fix.latitude,
        longitude: fix.longitude,
        capturedAt: fix.capturedAt,
      );
      setState(() {
        busy = false;
        error = null;
      });
      await _save();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = 'Konum alınamadı.';
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
      outcome = null;
    });
    final result = await ref.read(sessionProvider).submitPluxeeVisit(draft);
    if (!mounted) return;
    setState(() {
      busy = false;
      outcome = result;
      error = result.markedSuccess ? null : result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ready || catalog == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final step = steps[index];
    final review = step.kind == _Kind.review;
    return Scaffold(
      appBar: AppBar(
        title: Text('Pluxee ziyareti ${index + 1}/${steps.length}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _body(step),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: Dg.hi)),
          ],
          const SizedBox(height: 16),
          if (!review)
            FilledButton(
              onPressed: busy ? null : _forward,
              child: const Text('Devam'),
            ),
          if (index > 0) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : _back,
              child: const Text('Geri'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(_Step step) {
    switch (step.kind) {
      case _Kind.applied:
        return _yesNo(
          title: 'Sticker uygulandı mı?',
          value: draft.stickerApplied,
          onChanged: (value) {
            setState(() {
              draft.setStickerApplied(value);
              error = null;
              _clamp();
            });
            unawaited(_save());
          },
        );
      case _Kind.existing:
        return _tri(
          title: 'Pluxee sticker var mı?',
          value: draft.existingSticker,
          onChanged: (value) {
            setState(() => draft.existingSticker = value);
            unawaited(_save());
          },
        );
      case _Kind.echo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Display('Sticker uygulandı yanıtı', size: 28),
            const SizedBox(height: 12),
            Text(
              draft.stickerApplied == true ? 'Evet' : 'Hayır',
              style: Dg.ui(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Başlangıçtaki seçim. Bu adımda yeniden sorulmaz.',
              style: TextStyle(color: Dg.ink2),
            ),
          ],
        );
      case _Kind.other:
        return _tri(
          title: 'Başka yemek kartı var mı?',
          value: draft.otherMealCard,
          onChanged: (value) {
            setState(() => draft.otherMealCard = value);
            unawaited(_save());
          },
        );
      case _Kind.visual:
        return _yesNo(
          title: 'Görsel teslim edildi mi?',
          hint: 'Saha materyalinin teslimi. Fotoğraf yüklemesi ayrıdır.',
          value: draft.visualDelivered,
          onChanged: (value) {
            setState(() => draft.visualDelivered = value);
            unawaited(_save());
          },
        );
      case _Kind.note:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Display('Açıklama', size: 28),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Not'),
              onChanged: (value) => draft.note = value,
            ),
          ],
        );
      case _Kind.reason:
        return _options(
          title: 'İptal sebebi',
          options: [for (final group in catalog!.groups) group.reason],
          selected: draft.reasonKey,
          onChanged: (value) {
            setState(() {
              draft.setReason(value);
              error = null;
            });
            unawaited(_save());
          },
        );
      case _Kind.detail:
        final details = catalog!.detailsFor(draft.reasonKey ?? '');
        return _options(
          title: 'İptal açıklaması',
          options: details,
          selected: draft.detailKey,
          onChanged: (value) {
            setState(() => draft.setDetail(value));
            unawaited(_save());
          },
        );
      case _Kind.photo:
        return _photo(step.slot!);
      case _Kind.review:
        return _review();
    }
  }

  Widget _yesNo({
    required String title,
    required bool? value,
    required ValueChanged<bool> onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Display(title, size: 28),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(hint, style: TextStyle(color: Dg.ink2)),
        ],
        const SizedBox(height: 16),
        _pick('Evet', value == true, () => onChanged(true)),
        _pick('Hayır', value == false, () => onChanged(false)),
      ],
    );
  }

  Widget _tri({
    required String title,
    required PluxeeAnswer? value,
    required ValueChanged<PluxeeAnswer> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Display(title, size: 28),
        const SizedBox(height: 8),
        Text(
          'Bilinmiyor boş gider. Boş, Hayır değildir.',
          style: TextStyle(color: Dg.ink2),
        ),
        const SizedBox(height: 16),
        _pick(
          'Evet',
          value == PluxeeAnswer.yes,
          () => onChanged(PluxeeAnswer.yes),
        ),
        _pick(
          'Hayır',
          value == PluxeeAnswer.no,
          () => onChanged(PluxeeAnswer.no),
        ),
        _pick(
          'Bilinmiyor',
          value == PluxeeAnswer.unknown,
          () => onChanged(PluxeeAnswer.unknown),
        ),
      ],
    );
  }

  Widget _options({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Display(title, size: 28),
        const SizedBox(height: 16),
        for (final option in options)
          _pick(option, selected == option, () => onChanged(option)),
      ],
    );
  }

  Widget _pick(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? Dg.violetBg : Dg.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dg.radius),
          side: BorderSide(color: selected ? Dg.violet : Dg.rule),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dg.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(label, style: Dg.ui(size: 16, weight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _photo(String slot) {
    final photo = draft.photos[slot];
    final bytes = photo?.bytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Display(PluxeeSlots.labels[slot] ?? slot, size: 28),
        const SizedBox(height: 8),
        Text(
          'Çek, önizle, kullan veya tekrar çek. Kullanmadan devam edilmez.',
          style: TextStyle(color: Dg.ink2),
        ),
        const SizedBox(height: 16),
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(Dg.radius),
            child: Image.memory(
              bytes,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : _shoot,
          child: Text(photo == null ? 'Fotoğraf çek' : 'Tekrar çek'),
        ),
        if (photo != null && !photo.used) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              setState(() => draft.confirmPhoto(slot));
              unawaited(_save());
            },
            child: const Text('Fotoğrafı kullan'),
          ),
        ],
        if (photo != null && photo.used)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Kullanıldı', style: TextStyle(color: Dg.lo)),
          ),
        if (draft.cameraDenied)
          TextButton(
            onPressed: () => (widget.openSettings ?? openPluxeeSettings)(),
            child: const Text('Ayarlara git'),
          ),
      ],
    );
  }

  Widget _review() {
    final fresh = draft.locationFresh(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Display('Son kontrol', size: 28),
        const SizedBox(height: 12),
        Text('Sticker: ${draft.stickerApplied == true ? 'Evet' : 'Hayır'}'),
        Text(
          'Görsel teslim: ${draft.visualDelivered == true ? 'Evet' : 'Hayır'}',
        ),
        Text('Konum: ${fresh ? 'taze' : 'yok veya eski'}'),
        const SizedBox(height: 8),
        for (final photo in draft.submitPhotos)
          Text('${PluxeeSlots.labels[photo.slot]} kullanılacak'),
        for (final photo in draft.excludedPhotos)
          Text(
            '${PluxeeSlots.labels[photo.slot]} bu sonuçta gönderilmeyecek',
            style: TextStyle(color: Dg.ink2),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : _locate,
          child: const Text('Konumu kaydet'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: Text(busy ? 'Gönderiliyor' : 'Gönder'),
        ),
        if (outcome?.markedSuccess == true)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Form kaydedildi.'),
          ),
        if (outcome?.awaitingForm == true || outcome?.awaitingOps == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(outcome?.message ?? 'Taslak bekliyor.'),
          ),
      ],
    );
  }
}
