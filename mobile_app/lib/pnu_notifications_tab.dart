import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pnu_api.dart';
import 'providers.dart';

class PnuNotificationsTab extends ConsumerWidget {
  const PnuNotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(pnuNotificationsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pnuNotificationsProvider);
        await ref.read(pnuNotificationsProvider.future);
      },
      child: notifications.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
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
            Text('Could not load memos: $error'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => ref.invalidate(pnuNotificationsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (items) => items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 150),
                  Center(child: Icon(Icons.notifications_none, size: 52)),
                  SizedBox(height: 12),
                  Center(child: Text('No published memos or notices.')),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(item.title),
                      subtitle: Text(
                        [item.category, item.postingDate]
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _NotificationDetails(item: item),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationDetails extends StatelessWidget {
  const _NotificationDetails({required this.item});

  final PnuNotification item;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(item.title)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.category.isNotEmpty || item.postingDate.isNotEmpty)
          Text(
            [item.category, item.postingDate]
                .where((value) => value.isNotEmpty)
                .join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 16),
        SelectableText(item.details),
      ],
    ),
  );
}
