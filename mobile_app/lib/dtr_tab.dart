import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class DtrTab extends ConsumerWidget {
  const DtrTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(attendanceProvider);
    ref.invalidate(myDtrBatchesProvider);
    await ref.read(attendanceProvider.future);
    await ref.read(myDtrBatchesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final records = ref.watch(myDtrBatchesProvider);

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: records.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 200),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text('Could not load your DTR history: $error'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (batches) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Your daily time records',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Attendance punches appear immediately and are included when HR creates a DTR for that period.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _RecentAttendanceSection(),
            const SizedBox(height: 18),
            Text(
              'Official DTR periods',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (batches.isEmpty)
              _EmptyDtrCard()
            else
              for (final batch in batches) ...[
                _DtrBatchCard(
                  batch: batch,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _DtrDetailPage(batch: batch),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _RecentAttendanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attendance = ref.watch(attendanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent attendance logs',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Punches from the last 14 days.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        attendance.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text('Could not load attendance logs: $error'),
              trailing: IconButton(
                tooltip: 'Retry',
                onPressed: () => ref.invalidate(attendanceProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          data: (history) {
            final loggedDays = history.days.where(_hasPunches).toList();
            if (loggedDays.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No attendance punches in the last 14 days.'),
                ),
              );
            }

            return Column(
              children: [
                for (final day in loggedDays) ...[
                  _DtrDayCard(
                    entry: DtrEntry(
                      date: day.date,
                      status: day.status,
                      workedMinutes: day.workedMinutes,
                      checkInAt: day.checkInAt,
                      checkOutAt: day.checkOutAt,
                      amInAt: day.amInAt,
                      amOutAt: day.amOutAt,
                      pmInAt: day.pmInAt,
                      pmOutAt: day.pmOutAt,
                      otInAt: day.otInAt,
                      otOutAt: day.otOutAt,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  bool _hasPunches(AttendanceDay day) =>
      day.checkInAt != null ||
      day.checkOutAt != null ||
      day.amInAt != null ||
      day.amOutAt != null ||
      day.pmInAt != null ||
      day.pmOutAt != null ||
      day.otInAt != null ||
      day.otOutAt != null;
}

class _DtrBatchCard extends StatelessWidget {
  const _DtrBatchCard({required this.batch, required this.onTap});

  final DtrBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.periodLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${shortDate(batch.startDate)} – ${shortDate(batch.endDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      batch.code,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDtrCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 42,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 10),
            const Text('No official DTR periods are available yet.'),
            const SizedBox(height: 4),
            Text(
              'HR-generated periods will appear here when they are ready.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DtrDetailPage extends ConsumerWidget {
  const _DtrDetailPage({required this.batch});

  final DtrBatch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = ref.watch(myDtrDetailProvider(batch.id));

    return Scaffold(
      appBar: AppBar(title: Text(batch.periodLabel)),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load this DTR: $error'),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      ref.invalidate(myDtrDetailProvider(batch.id)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (record) {
          final employee = record.employees.firstOrNull;
          if (employee == null) {
            return const Center(child: Text('No employee record in this DTR.'));
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.code,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${shortDate(record.startDate)} – ${shortDate(record.endDate)}'
                      ' · Transaction ${shortDate(record.transactionDate)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if ((record.remarks ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        record.remarks!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: employee.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _DtrDayCard(entry: employee.entries[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DtrDayCard extends StatelessWidget {
  const _DtrDayCard({required this.entry});

  final DtrEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme, entry.status);
    final punches = [
      ('AM In', entry.amInAt),
      ('AM Out', entry.amOutAt),
      ('PM In', entry.pmInAt),
      ('PM Out', entry.pmOutAt),
      ('OT In', entry.otInAt),
      ('OT Out', entry.otOutAt),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${shortDate(entry.date)} · ${_weekday(entry.date.weekday)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  attendanceStatusLabel(entry.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, time) in punches)
                      SizedBox(
                        width: itemWidth,
                        child: _PunchTime(
                          label: label,
                          value: entry.timeLabelFor(time),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Worked ${entry.workedTimeLabel}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ThemeData theme, String status) => switch (status) {
    'present' => Colors.green,
    'late' => Colors.orange,
    'absent' => theme.colorScheme.error,
    'on_leave' => Colors.teal,
    'day_off' => theme.colorScheme.outline,
    _ => theme.colorScheme.onSurfaceVariant,
  };

  String _weekday(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];
}

class _PunchTime extends StatelessWidget {
  const _PunchTime({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
