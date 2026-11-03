import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class AppVersionBadge extends ConsumerWidget {
  const AppVersionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider);
    final color = Theme.of(context).colorScheme.onPrimary;

    return version.when(
      data: (value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.system_update_alt, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Version $value',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) {
        debugPrint('App version could not be read: $error\n$stackTrace');
        return const SizedBox.shrink();
      },
    );
  }
}
