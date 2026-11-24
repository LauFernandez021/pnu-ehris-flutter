import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_version_badge.dart';
import 'providers.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(pnuProfileProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pnuProfileProvider);
        await ref.read(pnuProfileProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: profile.maybeWhen(
                      data: (user) {
                        final name = user['name'] as String? ?? '';
                        return Text(name.isEmpty ? '?' : name[0].toUpperCase());
                      },
                      orElse: () => const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: profile.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(
                        'Could not load your profile: $error',
                        style: TextStyle(color: scheme.error),
                      ),
                      data: (user) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] as String? ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((user['employee_id'] as int?) != null)
                            Text('Employee ID ${user['employee_id']}'),
                          if ((user['email'] as String? ?? '').isNotEmpty)
                            Text(user['email'] as String),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'PNU EHRIS employee self-service',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'View posted biometric DTR records and published memos, and submit employee filing requests. Attendance is read-only in the mobile app.',
          ),
          const SizedBox(height: 16),
          const AppVersionBadge(),
        ],
      ),
    );
  }
}
