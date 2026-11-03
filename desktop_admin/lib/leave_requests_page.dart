import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers.dart';
import 'widgets.dart';

class LeaveRequestsPage extends ConsumerStatefulWidget {
  const LeaveRequestsPage({super.key});

  @override
  ConsumerState<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends ConsumerState<LeaveRequestsPage> {
  String _filter = 'pending';

  void _refresh() {
    ref.invalidate(leaveRequestsProvider);
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

  Future<void> _approve(LeaveRequest r) async {
    try {
      await LeaveService(ref.read(apiClientProvider)).approve(r.id);
      if (!mounted) return;
      _refresh();
      _snack("Approved ${r.employeeName}'s request");
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  Future<void> _reject(LeaveRequest r) async {
    final note = await askRejectionNote(context);
    if (note == null || !mounted) return;
    try {
      await LeaveService(ref.read(apiClientProvider)).reject(r.id, note);
      if (!mounted) return;
      _refresh();
      _snack('Request rejected');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  Future<void> _archive(LeaveRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive leave request?'),
        content: const Text(
          'Only rejected or cancelled requests can be archived. Request history is retained.',
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
      await LeaveService(ref.read(apiClientProvider)).archive(request.id);
      if (!mounted) return;
      _refresh();
      _snack('Leave request archived');
    } on ApiException catch (error) {
      if (mounted) _snack(error.message, error: true);
    }
  }

  Future<void> _viewAttachment(LeaveRequest r) async {
    try {
      final bytes = await ref
          .read(apiClientProvider)
          .getBytes('/leave-requests/${r.id}/attachment');
      if (!mounted) return;

      if ((r.attachmentName ?? '').toLowerCase().endsWith('.pdf')) {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}${Platform.pathSeparator}leave_${r.id}.pdf',
        );
        await file.writeAsBytes(bytes);
        await launchUrl(Uri.file(file.path));
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requests = ref.watch(leaveRequestsProvider(_filter));
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
                'Leave requests',
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
            child: requests.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(message: '$e', onRetry: _refresh),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
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
                  itemBuilder: (_, i) => _RequestTile(
                    request: list[i],
                    onApprove: () => _approve(list[i]),
                    onReject: () => _reject(list[i]),
                    onViewAttachment: list[i].hasAttachment
                        ? () => _viewAttachment(list[i])
                        : null,
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

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
    this.onViewAttachment,
    this.onArchive,
  });
  final LeaveRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onViewAttachment;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final r = request;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            InitialsAvatar(r.employeeName, radius: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        r.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(r.employeeNo, style: muted),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.leaveType} · ${shortDate(r.startDate)} – ${shortDate(r.endDate)} · ${daysText(r.days)}',
                  ),
                  if ((r.reason ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '"${r.reason}"',
                        style: muted.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  if (onViewAttachment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: Text(r.attachmentName ?? 'View attachment'),
                        onPressed: onViewAttachment,
                      ),
                    ),
                  if ((r.reviewNote ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Note: ${r.reviewNote}', style: muted),
                    ),
                ],
              ),
            ),
            StatusChip(r.status),
            if (onArchive != null)
              IconButton(
                tooltip: 'Archive',
                onPressed: onArchive,
                icon: const Icon(Icons.archive_outlined),
              ),
            if (r.isPending) ...[
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
