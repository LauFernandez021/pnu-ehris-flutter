import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class PnuDtrTab extends ConsumerWidget {
  const PnuDtrTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(pnuDtrProvider);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pnuDtrProvider);
        await ref.read(pnuDtrProvider.future);
      },
      child: records.when(
        loading: () => ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 220),
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
            Text('Could not load your DTR: $error'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => ref.invalidate(pnuDtrProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (periods) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Biometric DTR records',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Records are read-only and appear after they are posted in PNU EHRIS.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (periods.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No posted DTR periods are available.'),
                ),
              )
            else
              for (final period in periods) ...[
                Card(
                  child: ExpansionTile(
                    title: Text(
                      period.periodLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${period.code} · ${shortDate(period.startDate)} – ${shortDate(period.endDate)}',
                    ),
                    children: [
                      for (final employee in period.employees)
                        for (final entry in employee.entries)
                          ListTile(
                            dense: true,
                            title: Text(shortDate(entry.date)),
                            subtitle: Text(
                              'AM ${entry.timeLabelFor(entry.amInAt)} – ${entry.timeLabelFor(entry.amOutAt)}'
                              '   PM ${entry.timeLabelFor(entry.pmInAt)} – ${entry.timeLabelFor(entry.pmOutAt)}'
                              '${entry.otInAt == null && entry.otOutAt == null ? '' : '   OT ${entry.timeLabelFor(entry.otInAt)} – ${entry.timeLabelFor(entry.otOutAt)}'}',
                            ),
                            trailing: Text(
                              entry.workedMinutes > 0
                                  ? entry.workedTimeLabel
                                  : entry.status,
                            ),
                          ),
                    ],
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
