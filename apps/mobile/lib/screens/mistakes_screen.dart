import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/panel_models.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';

Color photoBandColor(String band) => switch (band) {
  'GOOD' => Dg.sage,
  'WATCH' => Dg.mid,
  'RISK' => Dg.hi,
  _ => Dg.ink3,
};

/// Fotoğraf puanı özeti; ana sayfada ve Hatalarım'ın başında kullanılır.
class PhotoScoreCard extends StatelessWidget {
  const PhotoScoreCard({super.key, required this.data, this.onTap});

  final PhotoMistakesDto data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final score = data.score;
    final color = photoBandColor(data.band);
    return DgCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.photoScoreTitle,
                  style: Dg.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Dg.ink2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  score == null
                      ? l.photoScoreUnrated(data.photos, data.minPhotos)
                      : l.photoScoreSummary(
                          data.photos,
                          data.rejected,
                          data.windowDays,
                        ),
                  style: Dg.ui(size: 13, color: Dg.ink3),
                ),
                if (data.unacknowledged > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l.mistakesTitle} · ${l.mistakesNew(data.unacknowledged)}',
                    style: Dg.ui(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Dg.hi,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Mono(
                score == null ? '—' : score.round().toString(),
                size: 26,
                weight: FontWeight.w700,
                color: color,
              ),
              if (score != null)
                Text(
                  l.photoBand(data.band),
                  style: Dg.ui(size: 12, weight: FontWeight.w600, color: color),
                ),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            DgIcon(LucideIcons.chevronRight, size: 16, color: Dg.ink3),
          ],
        ],
      ),
    );
  }
}

/// Kontrolde kabul edilmeyen fotoğraflar: neden, doğrusu ve "Okudum".
class MistakesScreen extends ConsumerStatefulWidget {
  const MistakesScreen({super.key});

  @override
  ConsumerState<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends ConsumerState<MistakesScreen> {
  final _files = <String, Future<List<int>>>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => ref.read(sessionProvider).loadPhotoMistakes();

  static String _date(DateTime? at) {
    if (at == null) return '';
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider);
    final data = s.photoMistakes;
    return Scaffold(
      appBar: AppBar(title: Text(l.mistakesTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (data == null)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: s.photoMistakesLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          l.mistakesEmpty,
                          style: Dg.ui(size: 15, color: Dg.ink2),
                        ),
                ),
              )
            else ...[
              PhotoScoreCard(data: data),
              const SizedBox(height: 16),
              if (data.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Text(
                      l.mistakesEmpty,
                      style: Dg.ui(size: 15, color: Dg.ink2),
                    ),
                  ),
                ),
              for (final m in data.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MistakeCard(
                    mistake: m,
                    date: _date(m.capturedAt),
                    file: _files.putIfAbsent(
                      m.evidenceId,
                      () => s.photoMistakeFile(m.evidenceId),
                    ),
                    onAck: () => ref
                        .read(sessionProvider)
                        .acknowledgePhotoMistake(m.evidenceId),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({
    required this.mistake,
    required this.date,
    required this.file,
    required this.onAck,
  });

  final PhotoMistakeDto mistake;
  final String date;
  final Future<List<int>> file;
  final VoidCallback onAck;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = mistake;
    final acked = m.acknowledgedAt != null;
    final hint = m.requirementHint;
    final reason = m.reason;
    return DgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dg.radius),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: FutureBuilder<List<int>>(
                future: file,
                builder: (context, snap) {
                  final bytes = snap.data;
                  if (bytes == null || bytes.isEmpty) {
                    return ColoredBox(
                      color: Dg.elev,
                      child: Center(
                        child: DgIcon(
                          LucideIcons.image,
                          size: 28,
                          color: Dg.ink3,
                        ),
                      ),
                    );
                  }
                  return Image.memory(
                    Uint8List.fromList(bytes),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.mistakeReason(m.reasonCode),
            style: Dg.ui(size: 16, weight: FontWeight.w700, color: Dg.hi),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason, style: Dg.ui(size: 15)),
          ],
          const SizedBox(height: 6),
          Text(
            [
              m.requirementLabel,
              if (m.shipmentNumber.isNotEmpty) m.shipmentNumber,
              if (date.isNotEmpty) date,
            ].where((e) => e.isNotEmpty).join(' · '),
            style: Dg.ui(size: 13, color: Dg.ink3),
          ),
          if (hint != null && hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l.mistakeHowTo}: $hint',
              style: Dg.ui(size: 14, color: Dg.ink2),
            ),
          ],
          const SizedBox(height: 12),
          if (acked)
            Row(
              children: [
                DgIcon(LucideIcons.circleCheck, size: 16, color: Dg.sage),
                const SizedBox(width: 6),
                Text(
                  l.mistakeAcked,
                  style: Dg.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Dg.sage,
                  ),
                ),
              ],
            )
          else
            DgButton(
              label: l.mistakeAck,
              icon: LucideIcons.check,
              onPressed: onAck,
            ),
        ],
      ),
    );
  }
}
