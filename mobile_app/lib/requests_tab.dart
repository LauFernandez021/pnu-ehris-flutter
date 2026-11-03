import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'dialogs.dart';
import 'pass_slip_card.dart';
import 'providers.dart';
import 'request_card.dart';

class RequestsTab extends ConsumerStatefulWidget {
  const RequestsTab({super.key});

  @override
  ConsumerState<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<RequestsTab> {
  String _kind = 'leave';

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelLeave(LeaveRequest r) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel request?',
      message: 'Cancel your ${r.leaveType} request starting ${shortDate(r.startDate)}?',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep it',
    );
    if (!ok || !mounted) return;
    try {
      await LeaveService(ref.read(apiClientProvider)).cancel(r.id);
      ref.invalidate(myRequestsProvider);
      ref.invalidate(balancesProvider);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _cancelSlip(PassSlip s) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel pass slip?',
      message: 'Cancel your pass slip for ${shortDate(s.slipDate)}?',
      confirmLabel: 'Cancel pass slip',
      cancelLabel: 'Keep it',
    );
    if (!ok || !mounted) return;
    try {
      await PassSlipService(ref.read(apiClientProvider)).cancel(s.id);
      ref.invalidate(myPassSlipsProvider);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Widget _empty(IconData icon, String text) {
    return ListView(children: [
      const SizedBox(height: 120),
      Center(
          child: Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline)),
      const SizedBox(height: 12),
      Center(child: Text(text)),
    ]);
  }

  Widget _error(Object e) => ListView(children: [
        Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
      ]);

  Widget _leaveList() {
    final requests = ref.watch(myRequestsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myRequestsProvider);
        await ref.read(myRequestsProvider.future);
      },
      child: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error(e),
        data: (list) {
          if (list.isEmpty) {
            return _empty(Icons.event_available_outlined,
                'You have no leave requests.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = list[i];
              return RequestCard(request: r, actions: [
                if (r.isPending)
                  TextButton(
                    onPressed: () => _cancelLeave(r),
                    child: const Text('Cancel request'),
                  ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _slipList() {
    final slips = ref.watch(myPassSlipsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myPassSlipsProvider);
        await ref.read(myPassSlipsProvider.future);
      },
      child: slips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error(e),
        data: (list) {
          if (list.isEmpty) {
            return _empty(Icons.directions_walk, 'You have no pass slips.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = list[i];
              return PassSlipCard(slip: s, actions: [
                if (s.isPending)
                  TextButton(
                    onPressed: () => _cancelSlip(s),
                    child: const Text('Cancel pass slip'),
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