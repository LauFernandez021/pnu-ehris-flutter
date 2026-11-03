import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class AttendanceTab extends ConsumerStatefulWidget {
  const AttendanceTab({super.key});

  @override
  ConsumerState<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<AttendanceTab> {
  Timer? _refreshTimer;
  bool _saving = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.invalidate(attendanceProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(attendanceProvider);
    await ref.read(attendanceProvider.future);
  }

  Future<void> _punch(String slot) async {
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      final service = AttendanceService(ref.read(apiClientProvider));
      await service.punch(slot);
      ref.invalidate(attendanceProvider);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'present' => Colors.green,
      'late' => Colors.orange,
      'absent' => scheme.error,
      'on_leave' => Colors.teal,
      'day_off' => scheme.outline,
      _ => scheme.primary,
    };
  }

  Widget _statusChip(BuildContext context, String status) {
    final color = _statusColor(context, status);
    return Chip(
      label: Text(attendanceStatusLabel(status)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _todayCard(AttendanceDay today, AttendanceSettings settings) {
    final theme = Theme.of(context);
    final isDayOff = today.status == 'day_off';
    final nextPunch = _nextPunch(today);
    final canStartOvertime = today.pmOutAt != null && today.otInAt == null;
    final punchValues = [
      ('AM In', today.amInAt),
      ('AM Out', today.amOutAt),
      ('PM In', today.pmInAt),
      ('PM Out', today.pmOutAt),
      ('OT In', today.otInAt),
      ('OT Out', today.otOutAt),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Today · ${shortDate(today.date)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(context, today.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Work hours ${settings.scheduleLabel} · ${settings.graceMinutes}-minute grace period',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 18,
              runSpacing: 16,
              children: [
                for (final (label, time) in punchValues)
                  SizedBox(
                    width: 92,
                    child: _PunchDetail(
                      icon: label.startsWith('OT')
                          ? Icons.more_time
                          : label.endsWith('In')
                          ? Icons.login
                          : Icons.logout,
                      label: label,
                      value: today.timeLabelFor(time),
                    ),
                  ),
                SizedBox(
                  width: 110,
                  child: _PunchDetail(
                    icon: Icons.schedule,
                    label: 'Hours worked',
                    value: today.workedTimeLabel,
                  ),
                ),
              ],
            ),
            if (_actionError != null) ...[
              const SizedBox(height: 12),
              Text(
                _actionError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: nextPunch != null && !isDayOff
                    ? FilledButton.icon(
                        key: ValueKey(nextPunch),
                        onPressed: _saving ? null : () => _punch(nextPunch),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                nextPunch.startsWith('ot')
                                    ? Icons.more_time
                                    : nextPunch.endsWith('in')
                                    ? Icons.login
                                    : Icons.logout,
                              ),
                        label: Text(
                          _saving
                              ? 'Saving...'
                              : 'Record ${_punchLabel(nextPunch)}',
                        ),
                      )
                    : canStartOvertime && !isDayOff
                    ? OutlinedButton.icon(
                        key: const ValueKey('start_overtime'),
                        onPressed: _saving ? null : () => _punch('ot_in'),
                        icon: const Icon(Icons.more_time),
                        label: const Text('Start optional overtime'),
                      )
                    : OutlinedButton.icon(
                        key: ValueKey(isDayOff ? 'day_off' : 'complete'),
                        onPressed: null,
                        icon: Icon(
                          isDayOff ? Icons.event_busy : Icons.task_alt,
                        ),
                        label: Text(
                          isDayOff
                              ? 'No punches on a day off'
                              : 'Scheduled punches complete',
                        ),
                      ),
              ),
            ),
            if (today.pmOutAt != null && today.otInAt == null) ...[
              const SizedBox(height: 8),
              Text(
                'AM and PM punches are complete. Overtime is optional.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _nextPunch(AttendanceDay day) {
    if (day.amInAt == null) return 'am_in';
    if (day.amOutAt == null) return 'am_out';
    if (day.pmInAt == null) return 'pm_in';
    if (day.pmOutAt == null) return 'pm_out';
    if (day.otInAt != null && day.otOutAt == null) return 'ot_out';
    return null;
  }

  String _punchLabel(String punch) => switch (punch) {
    'am_in' => 'AM In',
    'am_out' => 'AM Out',
    'pm_in' => 'PM In',
    'pm_out' => 'PM Out',
    'ot_in' => 'OT In',
    'ot_out' => 'OT Out',
    _ => punch,
  };

  Widget _historyTile(AttendanceDay day) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shortDate(day.date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _statusChip(context, day.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final (label, time) in [
                  ('AM In', day.amInAt),
                  ('AM Out', day.amOutAt),
                  ('PM In', day.pmInAt),
                  ('PM Out', day.pmOutAt),
                  ('OT In', day.otInAt),
                  ('OT Out', day.otOutAt),
                ])
                  Text(
                    '$label  ${day.timeLabelFor(time)}',
                    style: theme.textTheme.bodySmall,
                  ),
                Text(
                  'Worked ${day.workedTimeLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: attendance.when(
        loading: () => ListView(
          physics: AlwaysScrollableScrollPhysics(),
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
            Text('Could not load attendance: $error'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (history) {
          final today = history.days.first;
          final previousDays = history.days.skip(1);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _todayCard(today, history.settings),
              const SizedBox(height: 20),
              Text(
                'Recent attendance',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              for (final day in previousDays) ...[
                _historyTile(day),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PunchDetail extends StatelessWidget {
  const _PunchDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
