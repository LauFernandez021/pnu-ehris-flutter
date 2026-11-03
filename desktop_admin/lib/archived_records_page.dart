import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class ArchivedRecordsPage extends ConsumerStatefulWidget {
  const ArchivedRecordsPage({super.key});

  @override
  ConsumerState<ArchivedRecordsPage> createState() =>
      _ArchivedRecordsPageState();
}

class _ArchivedRecordsPageState extends ConsumerState<ArchivedRecordsPage> {
  String _category = 'employees';
  late Future<List<Map<String, dynamic>>> _records;
  bool _restoring = false;

  static const _categories = <String, String>{
    'employees': 'Employees',
    'departments': 'Departments',
    'leave-types': 'Leave types',
    'leave-requests': 'Leave requests',
    'pass-slips': 'Pass slips',
    'dtr-batches': 'DTR batches',
  };

  @override
  void initState() {
    super.initState();
    _records = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final api = ref.read(apiClientProvider);
    final path = switch (_category) {
      'leave-types' => '/settings/leave-types',
      _ => '/$_category',
    };
    final response = await api.get(path, query: {'trashed': 'only'});
    final items = response is Map ? response['data'] as List : response as List;
    return items
        .cast<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _refresh() => setState(() => _records = _load());

  Future<void> _restore(int id) async {
    setState(() => _restoring = true);
    try {
      final api = ref.read(apiClientProvider);
      final path = switch (_category) {
        'leave-types' => '/settings/leave-types/$id/restore',
        _ => '/$_category/$id/restore',
      };
      await api.post(path);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_categories[_category]} record restored.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  String _description(Map<String, dynamic> item) {
    final employee = item['employee'] as Map?;
    final employeeName = employee == null
        ? ''
        : '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'
              .trim();
    return switch (_category) {
      'employees' =>
        '${item['employee_no'] ?? ''} • ${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'
            .trim(),
      'departments' => item['name'] as String? ?? 'Department',
      'leave-types' =>
        '${item['name'] ?? 'Leave type'} • ${item['days_per_year'] ?? 0} days/year',
      'leave-requests' =>
        '$employeeName • ${item['status'] ?? ''} • ${item['start_date'] ?? ''} to ${item['end_date'] ?? ''}',
      'pass-slips' =>
        '$employeeName • ${item['status'] ?? ''} • ${item['slip_date'] ?? ''}',
      'dtr-batches' =>
        '${item['dtr_code'] ?? 'DTR'} • ${item['start_date'] ?? ''} to ${item['end_date'] ?? ''}',
      _ => 'Archived record',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Archived records', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Restore archived records. Archiving never permanently deletes data.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Module'),
                  items: _categories.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: _restoring
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _category = value;
                            _records = _load();
                          });
                        },
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _records,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load archived records: ${snapshot.error}',
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No archived ${_categories[_category]?.toLowerCase()}.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = item['id'] as int;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.archive_outlined),
                        ),
                        title: Text(_description(item)),
                        subtitle: Text('Record #$id'),
                        trailing: FilledButton.tonalIcon(
                          onPressed: _restoring ? null : () => _restore(id),
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
