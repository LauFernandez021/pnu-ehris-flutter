import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';
import 'widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  String _today() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${shortDate(d)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider)!;
    final summary = ref.watch(summaryProvider);
    final pending = ref.watch(leaveRequestsProvider('pending'));

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final firstName = session.user.name.split(' ').first;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '$greeting, $firstName',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _today(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        summary.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load summary: $e'),
          data: (s) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 270,
                child: StatCard(
                  icon: Icons.people,
                  label: 'Active employees',
                  value: '${s.activeEmployees}',
                  color: Colors.indigo,
                ),
              ),
              SizedBox(
                width: 270,
                child: StatCard(
                  icon: Icons.hourglass_top,
                  label: 'Pending leave requests',
                  value: '${s.pendingLeave}',
                  color: Colors.orange,
                ),
              ),
              SizedBox(
                width: 270,
                child: StatCard(
                  icon: Icons.beach_access,
                  label: 'On leave today',
                  value: '${s.onLeaveToday}',
                  color: Colors.teal,
                ),
              ),
              SizedBox(
                width: 270,
                child: StatCard(
                  icon: Icons.directions_walk,
                  label: 'Pass slips today',
                  value: '${s.passSlipsToday}',
                  color: Colors.blue,
                ),
              ),
              SizedBox(
                width: 270,
                child: StatCard(
                  icon: Icons.apartment,
                  label: 'Departments',
                  value: '${s.departments}',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for approval',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                pending.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                                   error: (e, _) => ErrorRetry(
                    message: '$e',
                    onRetry: () => ref.invalidate(leaveRequestsProvider),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 48,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 8),
                              const Text('All caught up. Nothing is waiting.'),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final r in list.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: InitialsAvatar(r.employeeName),
                            title: Text(r.employeeName),
                            subtitle: Text(
                              '${r.leaveType} · ${shortDate(r.startDate)} – ${shortDate(r.endDate)} · ${daysText(r.days)}',
                            ),
                            trailing: StatusChip(r.status),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
