import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key});

  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  final _action = TextEditingController();
  final _subjectType = TextEditingController();
  final _actorId = TextEditingController();
  final _subjectId = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  AuditLogPage? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _action.dispose();
    _subjectType.dispose();
    _actorId.dispose();
    _subjectId.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuditLogService(ref.read(apiClientProvider)).list(
        page: page,
        action: _action.text,
        subjectType: _subjectType.text,
        actorId: _actorId.text,
        subjectId: _subjectId.text,
        from: _from.text,
        to: _to.text,
      );
      if (mounted) setState(() => _result = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearFilters() {
    for (final controller in [
      _action,
      _subjectType,
      _actorId,
      _subjectId,
      _from,
      _to,
    ]) {
      controller.clear();
    }
    _load();
  }

  Widget _filter(
    String label,
    TextEditingController controller, {
    double width = 160,
    TextInputType? keyboardType,
    String? hint,
  }) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, hintText: hint),
      onSubmitted: (_) => _load(),
    ),
  );

  String _subjectLabel(AuditLogEntry entry) {
    final type = entry.subjectType?.split(r'\').last;
    if (type == null) return '-';
    return entry.subjectId == null ? type : '$type #${entry.subjectId}';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : () => _load(page: result?.currentPage ?? 1),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _filter('Action', _action, hint: 'e.g. employee.updated'),
                    _filter(
                      'Subject type',
                      _subjectType,
                      hint: 'e.g. Employee',
                      width: 180,
                    ),
                    _filter(
                      'Actor ID',
                      _actorId,
                      keyboardType: TextInputType.number,
                      width: 110,
                    ),
                    _filter(
                      'Subject ID',
                      _subjectId,
                      keyboardType: TextInputType.number,
                      width: 120,
                    ),
                    _filter('From', _from, width: 130, hint: 'YYYY-MM-DD'),
                    _filter('To', _to, width: 130, hint: 'YYYY-MM-DD'),
                    FilledButton.icon(
                      onPressed: _loading ? null : () => _load(),
                      icon: const Icon(Icons.search),
                      label: const Text('Filter'),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _clearFilters,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              MaterialBanner(
                content: Text(_error!),
                leading: const Icon(Icons.error_outline),
                actions: [
                  TextButton(
                    onPressed: _loading ? null : () => _load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _loading && result == null
                  ? const Center(child: CircularProgressIndicator())
                  : result == null || result.logs.isEmpty
                  ? Center(
                      child: Text(
                        _error == null
                            ? 'No audit events match these filters.'
                            : 'Audit events could not be loaded.',
                      ),
                    )
                  : Card(
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Time')),
                              DataColumn(label: Text('Actor')),
                              DataColumn(label: Text('Action')),
                              DataColumn(label: Text('Subject')),
                              DataColumn(label: Text('IP address')),
                              DataColumn(label: Text('Details')),
                            ],
                            rows: result.logs.map((entry) {
                              final actor = entry.actorName == null
                                  ? 'Unknown / failed login'
                                  : '${entry.actorName}\n${entry.actorEmail ?? ''}';
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '${shortDate(entry.createdAt.toLocal())} '
                                      '${entry.createdAt.toLocal().toString().substring(11, 16)}',
                                    ),
                                  ),
                                  DataCell(Text(actor)),
                                  DataCell(Text(entry.action)),
                                  DataCell(Text(_subjectLabel(entry))),
                                  DataCell(Text(entry.ip ?? '-')),
                                  DataCell(
                                    SizedBox(
                                      width: 240,
                                      child: Text(
                                        entry.meta.isEmpty
                                            ? '-'
                                            : jsonEncode(entry.meta),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
            ),
            if (result != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Page ${result.currentPage} of ${result.lastPage}'),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: _loading || result.currentPage <= 1
                        ? null
                        : () => _load(page: result.currentPage - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: _loading || result.currentPage >= result.lastPage
                        ? null
                        : () => _load(page: result.currentPage + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
