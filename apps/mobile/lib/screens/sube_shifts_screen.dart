import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/branch_models.dart';
import '../branch_workspace.dart';
import '../l10n.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'sube_widgets.dart';

/// Kuryelerin bugünkü planı / vardiyası ve izin istekleri.
class SubeShiftsScreen extends ConsumerStatefulWidget {
  const SubeShiftsScreen({super.key});

  @override
  ConsumerState<SubeShiftsScreen> createState() => _SubeShiftsScreenState();
}

class _SubeShiftsScreenState extends ConsumerState<SubeShiftsScreen> {
  int _tab = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider).branch.loadShifts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branch = ref.watch(sessionProvider).branch;
    final day = branch.shiftDay;
    final leaves = branch.leaves ?? const <LeaveRequest>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.subeShiftsTitle)),
      body: RefreshIndicator(
        onRefresh: branch.loadShifts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SegmentedTabs(
              labels: [l.subeShiftsTab, l.subeLeavesTab],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 12),
            SubeStatusBanner(branch: branch, onRetry: branch.loadShifts),
            if (day == null && branch.loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_tab == 0 && day != null) ...[
              SubeKpiGrid([
                (l.onShiftNow, '${day.onShiftNow} / ${day.courierCount}'),
                (l.plannedLabel, '${day.plannedCount}'),
                (l.plannedNotStarted, '${day.plannedNotStarted}'),
                (l.onLeaveLabel, '${day.onLeave}'),
              ]),
              for (final c in day.couriers) _ShiftTile(row: c),
            ],
            if (_tab == 1 && branch.leaves != null) ...[
              if (leaves.isEmpty)
                Text(l.nothingWaiting, style: Dg.ui(size: 13, color: Dg.ink3)),
              for (final r in leaves)
                _LeaveTile(
                  request: r,
                  canReview: branch.capabilities.manage && !_busy,
                  onReview: (approve) => _review(branch, r, approve),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BranchWorkspace branch,
    LeaveRequest request,
    bool approve,
  ) async {
    final l = context.l10n;
    String? note;
    if (!approve) {
      note = await _askReason();
      if (note == null || !mounted) return;
    }
    setState(() => _busy = true);
    final error = await branch.reviewLeave(
      request,
      approve: approve,
      note: note,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    subeSnack(context, error ?? (approve ? l.leaveApproved : l.leaveRejected));
  }

  Future<String?> _askReason() async {
    final l = context.l10n;
    final controller = TextEditingController();
    final note = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Dg.surface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reject, style: Dg.ui(size: 17, weight: FontWeight.w700)),
            TextField(
              controller: controller,
              maxLength: 500,
              decoration: InputDecoration(hintText: l.rejectReason),
            ),
            const SizedBox(height: 12),
            DgButton(
              label: l.reject,
              tone: DgButtonTone.danger,
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return note;
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({required this.row});

  final ShiftCourierRow row;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plan = switch (row.planStatus) {
      'PLANNED' => row.ranges.isEmpty ? l.plannedLabel : row.ranges,
      'ON_LEAVE' => l.onLeaveLabel,
      'OFF' => l.offLabel,
      _ => l.noPlanLabel,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DgCard(
        child: Row(
          children: [
            InitialsAvatar(name: row.name, size: 36, online: row.onShiftNow),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                  Text(plan, style: Dg.ui(size: 12, color: Dg.ink3)),
                  for (final f in row.flags)
                    Text(l.shiftFlag(f), style: Dg.ui(size: 12, color: Dg.mid)),
                ],
              ),
            ),
            if (row.onShiftNow) StatusChip(label: l.onShiftNow, tone: 'lo'),
          ],
        ),
      ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  const _LeaveTile({
    required this.request,
    required this.canReview,
    required this.onReview,
  });

  final LeaveRequest request;
  final bool canReview;
  final ValueChanged<bool> onReview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.courierName,
                    style: Dg.ui(size: 15, weight: FontWeight.w600),
                  ),
                ),
                if (!request.pending)
                  StatusChip(
                    label: request.approvalStatus == 'APPROVED'
                        ? l.leaveApproved
                        : l.leaveRejected,
                    tone: request.approvalStatus == 'APPROVED' ? 'lo' : 'hi',
                  ),
              ],
            ),
            Text(
              '${request.date} · '
              '${request.type == 'HOLIDAY' ? l.leaveHoliday : l.leaveLeave}',
              style: Dg.ui(size: 13, color: Dg.ink2),
            ),
            if (request.note.isNotEmpty)
              Text(request.note, style: Dg.ui(size: 12, color: Dg.ink3)),
            if (request.pending && canReview) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DgButton(
                      label: l.reject,
                      tone: DgButtonTone.secondary,
                      height: 44,
                      onPressed: () => onReview(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DgButton(
                      label: l.approve,
                      height: 44,
                      onPressed: () => onReview(true),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
