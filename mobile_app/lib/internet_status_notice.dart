import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'providers.dart';

class InternetStatusNotice extends ConsumerWidget {
  const InternetStatusNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(internetStatusProvider);
    final isDisconnected = switch (status) {
      AsyncData(value: InternetStatus.disconnected) => true,
      _ => false,
    };
    if (!isDisconnected) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 18, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet connection — connect before recording attendance.',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
