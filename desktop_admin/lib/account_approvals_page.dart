import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class AccountApprovalsPage extends ConsumerStatefulWidget {
  const AccountApprovalsPage({super.key});

  @override
  ConsumerState<AccountApprovalsPage> createState() =>
      _AccountApprovalsPageState();
}

class _AccountApprovalsPageState extends ConsumerState<AccountApprovalsPage> {
  String _tab = 'pending';

  void _refresh() {
    ref.invalidate(accountsProvider);
    ref.invalidate(employeesProvider);
    ref.invalidate(summaryProvider);
  }

  void _snack(String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
    ));
  }

  Future<void> _open(Employee emp) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ReviewDialog(employee: emp),
    );
    if (result == null || !mounted) return;

    final service = EmployeeService(ref.read(apiClientProvider));
    try {
      if (result['action'] == 'approve') {
        await service.approve(
          emp.id,
          departmentId: result['department_id'] as int?,
          position: result['position'] as String?,
          deviceUserId: result['device_user_id'] as String?,
        );
        if (!mounted) return;
        _refresh();
        _snack('${emp.fullName} can now sign in');
      } else {
        await service.reject(emp.id, result['note'] as String);
        if (!mounted) return;
        _refresh();
        _snack('Registration rejected');
      }
    } on ApiException catch (err) {
      if (mounted) _snack(err.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final accounts = ref.watch(accountsProvider(_tab));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Account approvals',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ]),
        const SizedBox(height: 4),
        Text('Employees who registered in the mobile app.', style: muted),
        const SizedBox(height: 16),
        Expanded(
          child: accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load: $e')),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_user_outlined,
                        size: 64, color: theme.colorScheme.outline),
                    const SizedBox(height: 8),
                    Text(switch (_tab) {
                      'approved' => 'No approved registrations yet.',
                      'rejected' => 'No rejected registrations.',
                      _ => 'No accounts waiting for approval.',
                    }),
                  ]),
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final emp = list[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        InitialsAvatar(emp.fullName, radius: 22),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(emp.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text('Employee no. ${emp.employeeNo} · ${emp.email ?? ''}',
                                  style: muted),
                              if (emp.reviewedAt != null)
                                Text('Reviewed ${shortDate(emp.reviewedAt!)}',
                                    style: muted),
                              if ((emp.reviewNote ?? '').isNotEmpty)
                                Text('Note: ${emp.reviewNote}', style: muted),
                            ],
                          ),
                        ),
                        StatusChip(emp.status),
                        const SizedBox(width: 16),
                        _tab == 'pending'
                            ? FilledButton(
                                onPressed: () => _open(emp),
                                child: const Text('Review'))
                            : OutlinedButton(
                                onPressed: () => _open(emp),
                                child: const Text('View')),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.employee});
  final Employee employee;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  late final TextEditingController _position;
  late final TextEditingController _deviceId;
  int? _departmentId;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _position = TextEditingController(text: e.position ?? '');
    _deviceId = TextEditingController(text: e.deviceUserId ?? '');
    _departmentId = e.departmentId;
  }

  @override
  void dispose() {
    _position.dispose();
    _deviceId.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    final note = await askRejectionNote(context);
    if (note == null || !mounted) return;
    Navigator.of(context).pop({'action': 'reject', 'note': note});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.employee;
    final departments = ref.watch(departmentsProvider);
    final canApprove = e.status != 'active';
    final canReject = e.status == 'pending';
    const gap = SizedBox(height: 18);

    return AlertDialog(
      title: Row(children: [
        InitialsAvatar(e.fullName),
        const SizedBox(width: 12),
        Expanded(child: Text(e.fullName)),
      ]),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee no. ${e.employeeNo}  ·  ${e.email ?? ''}'),
              if ((e.reviewNote ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Review note: ${e.reviewNote}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ],
              gap,
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _DocImage(
                        employeeId: e.id,
                        kind: 'id',
                        label: 'Company ID',
                        available: e.hasDocuments)),
                const SizedBox(width: 16),
                Expanded(
                    child: _DocImage(
                        employeeId: e.id,
                        kind: 'selfie',
                        label: 'Selfie holding the ID',
                        available: e.hasDocuments)),
              ]),
              if (canApprove) ...[
                const SizedBox(height: 28),
                Text('Set up the account',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600)),
                gap,
                departments.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Could not load departments: $err'),
                  data: (list) => DropdownButtonFormField<int?>(
                    initialValue: _departmentId,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('None')),
                      for (final d in list)
                        DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                ),
                gap,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextField(
                      controller: _position,
                      decoration: const InputDecoration(labelText: 'Position'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _deviceId,
                      decoration:
                          const InputDecoration(labelText: 'Biometric device ID'),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(canApprove ? 'Cancel' : 'Close'),
        ),
        if (canReject)
          OutlinedButton(onPressed: _reject, child: const Text('Reject')),
        if (canApprove)
          FilledButton(
            onPressed: () => Navigator.of(context).pop({
              'action': 'approve',
              'department_id': _departmentId,
              'position': _position.text,
              'device_user_id': _deviceId.text,
            }),
            child: Text(e.status == 'rejected' ? 'Approve anyway' : 'Approve'),
          ),
      ],
    );
  }
}

class _DocImage extends ConsumerWidget {
  const _DocImage({
    required this.employeeId,
    required this.kind,
    required this.label,
    required this.available,
  });
  final int employeeId;
  final String kind;
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final token = ref.watch(sessionProvider)?.token ?? '';
    final url = '$apiBaseUrl/employees/$employeeId/documents/$kind';
    final headers = {'Authorization': 'Bearer $token', 'Accept': 'image/*'};

    Widget box(Widget child) => Container(
          height: 260,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (!available)
        box(const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No photo submitted.', textAlign: TextAlign.center),
        ))
      else ...[
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(
                child: Image.network(url, headers: headers),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: box(Image.network(
              url,
              headers: headers,
              fit: BoxFit.contain,
              loadingBuilder: (c, child, p) => p == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) => const Text('Could not load the photo.'),
            )),
          ),
        ),
        const SizedBox(height: 4),
        Text('Click the photo to enlarge', style: theme.textTheme.bodySmall),
      ],
    ]);
  }
}