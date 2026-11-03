import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'widgets.dart';
import 'providers.dart';

class PassSlipsPage extends ConsumerStatefulWidget {
  const PassSlipsPage({super.key});

  @override
  ConsumerState<PassSlipsPage> createState() => _PassSlipsPageState();
}

class _PassSlipsPageState extends ConsumerState<PassSlipsPage> {
  String _filter = 'pending';

  void _refresh() {
    ref.invalidate(passSlipsProvider);
    ref.invalidate(summaryProvider);
  }

  void _snack(String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.error : null,
      ),
    );
  }

  Future<void> _approve(PassSlip s) async {
    try {
      await PassSlipService(ref.read(apiClientProvider)).approve(s.id);
      if (!mounted) return;
      _refresh();
      _snack("Approved ${s.employeeName}'s pass slip");
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  Future<void> _reject(PassSlip s) async {
    final note = await askRejectionNote(context);
    if (note == null || !mounted) return;
    try {
      await PassSlipService(ref.read(apiClientProvider)).reject(s.id, note);
      if (!mounted) return;
      _refresh();
      _snack('Pass slip rejected');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  Future<void> _archive(PassSlip slip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive pass slip?'),
        content: const Text(
          'Only rejected or cancelled pass slips can be archived. Request history is retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PassSlipService(ref.read(apiClientProvider)).archive(slip.id);
      if (!mounted) return;
      _refresh();
      _snack('Pass slip archived');
    } on ApiException catch (error) {
      if (mounted) _snack(error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slips = ref.watch(passSlipsProvider(_filter));
    final canArchive =
        ref
            .watch(sessionProvider)
            ?.roles
            .any((role) => role == 'admin' || role == 'hr') ??
        false;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pass slips',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: Text('Pending')),
                  ButtonSegment(value: 'approved', label: Text('Approved')),
                  ButtonSegment(value: 'rejected', label: Text('Rejected')),
                  ButtonSegment(value: '', label: Text('All')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: slips.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(message: '$e', onRetry: _refresh),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_walk,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        const Text('Nothing here.'),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _SlipTile(
                    slip: list[i],
                    onApprove: () => _approve(list[i]),
                    onReject: () => _reject(list[i]),
                    onArchive:
                        canArchive &&
                            list[i].status != 'pending' &&
                            list[i].status != 'approved'
                        ? () => _archive(list[i])
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SlipTile extends StatelessWidget {
  const _SlipTile({
    required this.slip,
    required this.onApprove,
    required this.onReject,
    this.onArchive,
  });
  final PassSlip slip;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final s = slip;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            InitialsAvatar(s.employeeName, radius: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        s.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(s.employeeNo, style: muted),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.typeLabel} · ${shortDate(s.slipDate)} · ${timeLabel(s.timeOut)} – ${timeLabel(s.timeIn)}',
                  ),
                  Text('To: ${s.destination}', style: muted),
                  if ((s.reason ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '"${s.reason}"',
                        style: muted.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  if ((s.reviewNote ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Note: ${s.reviewNote}', style: muted),
                    ),
                ],
              ),
            ),
            StatusChip(s.status),
            if (onArchive != null)
              IconButton(
                tooltip: 'Archive',
                onPressed: onArchive,
                icon: const Icon(Icons.archive_outlined),
              ),
            if (s.isPending) ...[
              const SizedBox(width: 16),
              OutlinedButton(onPressed: onReject, child: const Text('Reject')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onApprove, child: const Text('Approve')),
            ],
          ],
        ),
      ),
    );
  }
}
