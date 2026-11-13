import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Gönderinin `courier-jobs` işlem geçmişi. Adlar `locale` ile gelir.
class SubeJobScreen extends ConsumerStatefulWidget {
  const SubeJobScreen({
    super.key,
    required this.shipmentId,
    required this.shipmentNumber,
  });

  final String shipmentId;
  final String shipmentNumber;

  @override
  ConsumerState<SubeJobScreen> createState() => _SubeJobScreenState();
}

class _SubeJobScreenState extends ConsumerState<SubeJobScreen> {
  CourierJobsView? _view;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final l = context.l10n;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final view = await ref.read(sessionProvider).branch.courierJobs(
        widget.shipmentId,
        locale: l.isEn ? 'en' : 'tr',
      );
      if (!mounted) return;
      setState(() {
        _view = view;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = BranchWorkspace.describeError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final events = _view?.recent ?? const <JobHistoryEvent>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.jobHistory)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Mono(widget.shipmentNumber, size: 15, weight: FontWeight.w700),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!, style: Dg.ui(size: 14, color: Dg.hi))
            else if (events.isEmpty)
              DgEmptyState(icon: LucideIcons.history, title: l.jobHistoryEmpty)
            else
              for (final event in events.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DgCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.headline.isNotEmpty)
                          Text(
                            event.headline,
                            style: Dg.ui(size: 15, weight: FontWeight.w600),
                          ),
                        if (event.altLine != null)
                          Text(
                            event.altLine!,
                            style: Dg.ui(size: 13, color: Dg.ink2),
                          ),
                        if (event.reasonName != null &&
                            event.reasonName!.isNotEmpty)
                          Text(
                            event.reasonName!,
                            style: Dg.ui(size: 13, color: Dg.ink2),
                          ),
                        Text(
                          [
                            if (event.sourceName != null &&
                                event.sourceName!.isNotEmpty)
                              event.sourceName!,
                            if (event.actor != null && event.actor!.isNotEmpty)
                              event.actor!,
                            if (event.at != null) subeDayTime(event.at!),
                          ].join(' · '),
                          style: Dg.ui(size: 12, color: Dg.ink3),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
