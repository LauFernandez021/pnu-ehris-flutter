import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';
import 'widgets.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  DateTime _date = DateTime.now();
  String _filter = 'all';
  String _query = '';

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _refresh() {
    ref.invalidate(attendanceReportProvider(ymd(_date)));
  }

  Widget _stat(
    BuildContext context,
    String label,
    int value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 220,
      child: StatCard(icon: icon, label: label, value: '$value', color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = ref.watch(attendanceReportProvider(ymd(_date)));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Attendance',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(shortDate(_date)),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Daily punches and attendance status',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorRetry(
                message: 'Could not load attendance: $error',
                onRetry: _refresh,
              ),
              data: (data) {
                final query = _query.trim().toLowerCase();
                final days = data.days.where((day) {
                  final matchesStatus =
                      _filter == 'all' || day.status == _filter;
                  final searchable =
                      '${day.employeeName ?? ''} ${day.employeeNo ?? ''} ${day.department ?? ''}'
                          .toLowerCase();
                  return matchesStatus &&
                      (query.isEmpty || searchable.contains(query));
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _stat(
                          context,
                          'Present',
                          data.counts['present'] ?? 0,
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                        _stat(
                          context,
                          'Late',
                          data.counts['late'] ?? 0,
                          Icons.schedule,
                          Colors.orange,
                        ),
                        _stat(
                          context,
                          'Absent',
                          data.counts['absent'] ?? 0,
                          Icons.person_off_outlined,
                          theme.colorScheme.error,
                        ),
                        _stat(
                          context,
                          'On leave',
                          data.counts['on_leave'] ?? 0,
                          Icons.beach_access_outlined,
                          Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Work hours ${data.settings.scheduleLabel} · '
                      '${data.settings.graceMinutes}-minute grace period',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: 360,
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Search employee or department',
                                isDense: true,
                              ),
                              onChanged: (value) =>
                                  setState(() => _query = value),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('All')),
                            ButtonSegment(
                              value: 'present',
                              label: Text('Present'),
                            ),
                            ButtonSegment(value: 'late', label: Text('Late')),
                            ButtonSegment(
                              value: 'absent',
                              label: Text('Absent'),
                            ),
                            ButtonSegment(
                              value: 'on_leave',
                              label: Text('On leave'),
                            ),
                          ],
                          selected: {_filter},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) =>
                              setState(() => _filter = selection.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: days.isEmpty
                          ? Center(
                              child: Text(
                                data.days.isEmpty
                                    ? 'No active employees for this date.'
                                    : 'No employees match this filter.',
                              ),
                            )
                          : Card(
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Employee')),
                                      DataColumn(label: Text('Department')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('AM In')),
                                      DataColumn(label: Text('AM Out')),
                                      DataColumn(label: Text('PM In')),
                                      DataColumn(label: Text('PM Out')),
                                      DataColumn(label: Text('OT In')),
                                      DataColumn(label: Text('OT Out')),
                                      DataColumn(label: Text('Hours worked')),
                                    ],
                                    rows: [
                                      for (final day in days)
                                        DataRow(
                                          cells: [
                                            DataCell(
                                              Row(
                                                children: [
                                                  InitialsAvatar(
                                                    day.employeeName ?? '',
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        day.employeeName ?? '',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        day.employeeNo ?? '',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Text(day.department ?? '—'),
                                            ),
                                            DataCell(
                                              _AttendanceStatusChip(
                                                status: day.status,
                                              ),
                                            ),
                                            DataCell(
                                              Text(day.timeLabelFor(day.amInAt)),
                                            ),
                                            DataCell(
                                              Text(day.timeLabelFor(day.amOutAt)),
                                            ),
                                            DataCell(
                                              Text(day.timeLabelFor(day.pmInAt)),
                                            ),
                                            DataCell(
                                              Text(day.timeLabelFor(day.pmOutAt)),
                                            ),
                                            DataCell(
                                              Text(day.timeLabelFor(day.otInAt)),
                                            ),
                                            DataCell(
                                              Text(day.timeLabelFor(day.otOutAt)),
                                            ),
                                            DataCell(Text(day.workedTimeLabel)),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceStatusChip extends StatelessWidget {
  const _AttendanceStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'present' => Colors.green,
      'late' => Colors.orange,
      'absent' => scheme.error,
      'on_leave' => Colors.teal,
      'day_off' => scheme.outline,
      _ => scheme.primary,
    };

    return Chip(
      label: Text(attendanceStatusLabel(status)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
    );
  }
}
