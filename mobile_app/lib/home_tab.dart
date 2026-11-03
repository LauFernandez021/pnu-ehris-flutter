import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';
import 'request_card.dart';
import 'app_version_badge.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = ref.watch(sessionProvider)!;
    final balances = ref.watch(balancesProvider);
    final requests = ref.watch(myRequestsProvider);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myRequestsProvider);
        ref.invalidate(balancesProvider);
        await ref.read(balancesProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
                  child: Text(
                    session.user.name.isEmpty
                        ? '?'
                        : session.user.name[0].toUpperCase(),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        session.user.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        shortDate(DateTime.now()),
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const AppVersionBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Leave balance',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          balances.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: TextStyle(color: scheme.error)),
            data: (list) => list.isEmpty
                ? const Text('No leave types set up yet.')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 340 ? 2 : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: columns == 2 ? 1.55 : 2.4,
                        ),
                        itemBuilder: (_, i) => _BalanceCard(list[i]),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent requests',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          requests.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: TextStyle(color: scheme.error)),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.beach_access_outlined,
                          size: 48,
                          color: scheme.outline,
                        ),
                        const SizedBox(height: 8),
                        const Text('No requests yet. Time for a break?'),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in list.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RequestCard(request: r),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard(this.balance);
  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = balance;
    final progress = b.allocated == 0
        ? 0.0
        : (b.used / b.allocated).clamp(0.0, 1.0);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              b.leaveType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  dayLabel(b.remaining),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 5),
                Text('days left', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 5),
            ),
            const SizedBox(height: 5),
            Text(
              'Used ${dayLabel(b.used)} of ${dayLabel(b.allocated)}'
              '${b.pending > 0 ? ' · ${dayLabel(b.pending)} pending' : ''}',
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
