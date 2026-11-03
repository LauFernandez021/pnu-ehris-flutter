import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'pass_slip_card.dart';
import 'providers.dart';
import 'request_card.dart';
import 'attachment_viewer.dart';


class ApprovalsTab extends ConsumerStatefulWidget {
  const ApprovalsTab({super.key});

  @override
  ConsumerState<ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends ConsumerState<ApprovalsTab> {
  String _kind = 'leave';

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(approvalsProvider);
      ref.invalidate(passSlipApprovalsProvider);
      _snack(done);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _rejectWith(Future<void> Function(String note) action) async {
    final note = await askRejectionNote(context);
    if (note == null || !mounted) return;
    await _run(() => action(note), 'Rejected');
  }

  Widget _empty() {
    return ListView(children: [
      const SizedBox(height: 120),
      Center(
          child: Icon(Icons.check_circle_outline,
              size: 64, color: Colors.green.shade400)),
      const SizedBox(height: 12),
      const Center(child: Text('All caught up. Nothing to approve.')),
    ]);
  }

  Widget _error(Object e) => ListView(children: [
        Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
      ]);

  Widget _leaveList() {
    final approvals = ref.watch(approvalsProvider);
    final service = LeaveService(ref.read(apiClientProvider));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(approvalsProvider);
        await ref.read(approvalsProvider.future);
      },
      child: approvals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error(e),
        data: (list) {
          if (list.isEmpty) return _empty();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = list[i];
                            return RequestCard(
                  request: r,
                  showEmployee: true,
                  onViewAttachment: r.hasAttachment
                      ? () => viewLeaveAttachment(context, ref, r)
                      : null,
                  actions: [
                TextButton(
                  onPressed: () => _rejectWith((n) => service.reject(r.id, n)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _run(() => service.approve(r.id),
                      "Approved ${r.employeeName}'s request"),
                  child: const Text('Approve'),
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _slipList() {
    final approvals = ref.watch(passSlipApprovalsProvider);
    final service = PassSlipService(ref.read(apiClientProvider));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(passSlipApprovalsProvider);
        await ref.read(passSlipApprovalsProvider.future);
      },
      child: approvals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error(e),
        data: (list) {
          if (list.isEmpty) return _empty();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = list[i];
              return PassSlipCard(slip: s, showEmployee: true, actions: [
                TextButton(
                  onPressed: () => _rejectWith((n) => service.reject(s.id, n)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _run(() => service.approve(s.id),
                      "Approved ${s.employeeName}'s pass slip"),
                  child: const Text('Approve'),
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'leave', label: Text('Leave')),
              ButtonSegment(value: 'slips', label: Text('Pass slips')),
            ],
            selected: {_kind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
        ),
      ),
      Expanded(child: _kind == 'leave' ? _leaveList() : _slipList()),
    ]);
  }
}