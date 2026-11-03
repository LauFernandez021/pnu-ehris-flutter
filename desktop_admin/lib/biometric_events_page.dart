import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class BiometricEventsPage extends ConsumerStatefulWidget {
  const BiometricEventsPage({super.key});

  @override
  ConsumerState<BiometricEventsPage> createState() =>
      _BiometricEventsPageState();
}

class _BiometricEventsPageState extends ConsumerState<BiometricEventsPage> {
  String _mapping = '';
  late Future<List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response =
        await ref
                .read(apiClientProvider)
                .get(
                  '/biometric/events',
                  query: {
                    'per_page': 200,
                    if (_mapping.isNotEmpty) 'mapping': _mapping,
                  },
                )
            as Map<String, dynamic>;
    return (response['data'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void _refresh() => setState(() => _events = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biometric device logs', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Captured ADMS records are retained here for verification. They do not update attendance or DTRs automatically.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '', label: Text('All')),
                  ButtonSegment(value: 'mapped', label: Text('Mapped')),
                  ButtonSegment(value: 'unmapped', label: Text('Unmapped')),
                ],
                selected: {_mapping},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mapping = selection.first;
                    _events = _load();
                  });
                },
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
              future: _events,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load device events: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final events = snapshot.data ?? const [];
                if (events.isEmpty) {
                  return const Center(
                    child: Text('No biometric events received yet.'),
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Punch time')),
                          DataColumn(label: Text('Employee')),
                          DataColumn(label: Text('Device user ID')),
                          DataColumn(label: Text('Device serial')),
                          DataColumn(label: Text('Verification')),
                          DataColumn(label: Text('Device state')),
                          DataColumn(label: Text('Mapping')),
                        ],
                        rows: [
                          for (final event in events)
                            DataRow(
                              cells: [
                                DataCell(Text(_formatPunch(event['punch_at']))),
                                DataCell(
                                  Text(_employeeName(event['employee'])),
                                ),
                                DataCell(Text('${event['device_user_id']}')),
                                DataCell(Text('${event['device_serial']}')),
                                DataCell(
                                  Text('${event['verify_type'] ?? '—'}'),
                                ),
                                DataCell(
                                  Text('${event['punch_state'] ?? '—'}'),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      event['employee'] == null
                                          ? 'Unmapped'
                                          : 'Mapped',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _employeeName(dynamic data) {
    if (data is! Map) return 'No matching employee';
    final first = data['first_name'] ?? '';
    final last = data['last_name'] ?? '';
    return '$first $last'.trim();
  }

  String _formatPunch(dynamic value) {
    if (value is! String) return '—';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final date = shortDate(local);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$date  $hour:$minute $period';
  }
}
