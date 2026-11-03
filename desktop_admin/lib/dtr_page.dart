import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';
import 'widgets.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class DtrPage extends ConsumerWidget {
  const DtrPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<DtrBatch>(
      context: context,
      builder: (_) => const _CreateDtrDialog(),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(dtrBatchesProvider);
    await _showDetails(context, created);
  }

  Future<void> _showDetails(BuildContext context, DtrBatch summary) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DtrDetailsDialog(batchId: summary.id),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    DtrBatch batch,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive DTR batch?'),
        content: Text(
          '${batch.code} will be hidden from active DTR lists. Its employee and punch snapshots will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DtrService(ref.read(apiClientProvider)).archive(batch.id);
      if (!context.mounted) return;
      ref.invalidate(dtrBatchesProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${batch.code} archived.')));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final batches = ref.watch(dtrBatchesProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Daily time records',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(dtrBatchesProvider),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create DTR'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Create monthly or semi-monthly DTRs from recorded attendance punches.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: batches.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorRetry(
                message: 'Could not load DTR records: $error',
                onRetry: () => ref.invalidate(dtrBatchesProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 60,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text('No DTRs created yet.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _create(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Create your first DTR'),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('DTR code')),
                          DataColumn(label: Text('Period')),
                          DataColumn(label: Text('From')),
                          DataColumn(label: Text('To')),
                          DataColumn(label: Text('Transaction date')),
                          DataColumn(label: Text('Employees')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [
                          for (final batch in list)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    batch.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DataCell(Text(batch.periodLabel)),
                                DataCell(Text(shortDate(batch.startDate))),
                                DataCell(Text(shortDate(batch.endDate))),
                                DataCell(
                                  Text(shortDate(batch.transactionDate)),
                                ),
                                DataCell(Text('${batch.employeeCount}')),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showDetails(context, batch),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        label: const Text('View'),
                                      ),
                                      IconButton(
                                        tooltip: 'Archive',
                                        onPressed: () =>
                                            _archive(context, ref, batch),
                                        icon: const Icon(
                                          Icons.archive_outlined,
                                        ),
                                      ),
                                    ],
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
}

class _CreateDtrDialog extends ConsumerStatefulWidget {
  const _CreateDtrDialog();

  @override
  ConsumerState<_CreateDtrDialog> createState() => _CreateDtrDialogState();
}

class _CreateDtrDialogState extends ConsumerState<_CreateDtrDialog> {
  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  final _remarksController = TextEditingController();
  final _employeeSearchController = TextEditingController();
  int _step = 0;
  int _month = DateTime.now().month;
  DateTime _transactionDate = DateTime.now();
  String _periodType = 'monthly';
  String _payPeriod = 'first_cutoff';
  String _employeeSelection = 'all';
  String _employeeQuery = '';
  final Set<int> _selectedEmployeeIds = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _yearController.dispose();
    _remarksController.dispose();
    _employeeSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickTransactionDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1),
    );
    if (picked != null) {
      setState(() => _transactionDate = picked);
    }
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _step = 1;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_employeeSelection == 'selected' && _selectedEmployeeIds.isEmpty) {
      setState(() => _error = 'Select at least one employee for this DTR.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final batch = await DtrService(ref.read(apiClientProvider)).create(
        periodType: _periodType,
        payPeriod: _periodType == 'semi_monthly' ? _payPeriod : null,
        year: int.parse(_yearController.text),
        month: _month,
        transactionDate: ymd(_transactionDate),
        allEmployees: _employeeSelection == 'all',
        employeeIds: _selectedEmployeeIds.toList(),
        remarks: _remarksController.text,
      );
      if (mounted) Navigator.of(context).pop(batch);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _periodForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _periodType,
                  decoration: const InputDecoration(labelText: 'DTR type'),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(
                      value: 'semi_monthly',
                      child: Text('Semi-monthly'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _periodType = value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: [
                    for (var month = 1; month <= 12; month++)
                      DropdownMenuItem(
                        value: month,
                        child: Text(_months[month - 1]),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _month = value);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final year = int.tryParse(value ?? '');
                    if (year == null || year < 2000 || year > 2100) {
                      return 'Enter a year from 2000 to 2100.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          if (_periodType == 'semi_monthly') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _payPeriod,
              decoration: const InputDecoration(labelText: 'Pay period'),
              items: const [
                DropdownMenuItem(
                  value: 'first_cutoff',
                  child: Text('1st cutoff · 1–15'),
                ),
                DropdownMenuItem(
                  value: 'second_cutoff',
                  child: Text('2nd cutoff · 16–end of month'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _payPeriod = value);
              },
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTransactionDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    'Transaction date · ${shortDate(_transactionDate)}',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _remarksController,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (optional)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _periodType == 'monthly'
                  ? 'DTR dates: ${_months[_month - 1]} 1–$_periodEndDay'
                  : _payPeriod == 'first_cutoff'
                  ? 'DTR dates: ${_months[_month - 1]} 1–15'
                  : 'DTR dates: ${_months[_month - 1]} 16–$_periodEndDay',
            ),
          ),
        ],
      ),
    );
  }

  int get _periodEndDay {
    final year = int.tryParse(_yearController.text) ?? DateTime.now().year;
    return DateTime(year, _month + 1, 0).day;
  }

  Widget _employeePicker(List<DtrEmployeeOption> employees) {
    final filtered = employees.where((employee) {
      final query = _employeeQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return '${employee.name} ${employee.employeeNo} ${employee.department ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'all',
              label: Text('All active employees'),
              icon: Icon(Icons.groups_outlined),
            ),
            ButtonSegment(
              value: 'selected',
              label: Text('Select employees'),
              icon: Icon(Icons.person_search_outlined),
            ),
          ],
          selected: {_employeeSelection},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            setState(() {
              _employeeSelection = selection.first;
              _error = null;
            });
          },
        ),
        const SizedBox(height: 12),
        if (_employeeSelection == 'all')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The DTR will include all ${employees.length} active employees.',
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          TextField(
            controller: _employeeSearchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, employee number, department',
              isDense: true,
            ),
            onChanged: (value) => setState(() => _employeeQuery = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${_selectedEmployeeIds.length} selected'),
              const Spacer(),
              TextButton(
                onPressed: () => setState(
                  () => _selectedEmployeeIds.addAll(
                    filtered.map((employee) => employee.id),
                  ),
                ),
                child: const Text('Select shown'),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _selectedEmployeeIds.removeAll(
                    filtered.map((employee) => employee.id),
                  ),
                ),
                child: const Text('Clear shown'),
              ),
            ],
          ),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final employee = filtered[index];
                  return CheckboxListTile(
                    value: _selectedEmployeeIds.contains(employee.id),
                    onChanged: (selected) => setState(() {
                      if (selected == true) {
                        _selectedEmployeeIds.add(employee.id);
                      } else {
                        _selectedEmployeeIds.remove(employee.id);
                      }
                    }),
                    title: Text(employee.name),
                    subtitle: Text(
                      [
                        employee.employeeNo,
                        if (employee.designation?.isNotEmpty == true)
                          employee.designation!,
                        if (employee.department?.isNotEmpty == true)
                          employee.department!,
                      ].join(' · '),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(dtrEmployeesProvider);
    final theme = Theme.of(context);

    return Dialog(
      child: SizedBox(
        width: 850,
        height: 650,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Create daily time record',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _WizardStep(
                    number: 1,
                    label: 'DTR period',
                    selected: _step == 0,
                  ),
                  const SizedBox(width: 24),
                  _WizardStep(
                    number: 2,
                    label: 'Employees',
                    selected: _step == 1,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: _step == 0
                    ? SingleChildScrollView(child: _periodForm())
                    : employees.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Could not load employees: $error'),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: () =>
                                    ref.invalidate(dtrEmployeesProvider),
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                        data: (list) => _employeePicker(list),
                      ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving || _step == 0
                        ? null
                        : () => setState(() {
                            _step = 0;
                            _error = null;
                          }),
                    child: const Text('Back'),
                  ),
                  const Spacer(),
                  if (_step == 0)
                    FilledButton.icon(
                      onPressed: _continue,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save DTR'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardStep extends StatelessWidget {
  const _WizardStep({
    required this.number,
    required this.label,
    required this.selected,
  });

  final int number;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: selected
              ? scheme.primary
              : scheme.surfaceContainerHighest,
          foregroundColor: selected
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
          child: Text('$number', style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _DtrDetailsDialog extends ConsumerWidget {
  const _DtrDetailsDialog({required this.batchId});

  final int batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final batch = ref.watch(dtrDetailsProvider(batchId));

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 780),
        child: SizedBox(
          width: 1150,
          height: 740,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: batch.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorRetry(
                message: 'Could not load DTR details: $error',
                onRetry: () => ref.invalidate(dtrDetailsProvider(batchId)),
              ),
              data: (record) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily time record · ${record.code}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Review the employees included in this DTR and open an employee to view every daily punch.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _DtrMetadata(
                          label: 'Period',
                          value: record.periodLabel,
                        ),
                        _DtrMetadata(
                          label: 'Start date',
                          value: shortDate(record.startDate),
                        ),
                        _DtrMetadata(
                          label: 'End date',
                          value: shortDate(record.endDate),
                        ),
                        _DtrMetadata(
                          label: 'Transaction date',
                          value: shortDate(record.transactionDate),
                        ),
                        _DtrMetadata(
                          label: 'Employees',
                          value: '${record.employeeCount}',
                        ),
                      ],
                    ),
                    if ((record.remarks ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Remarks: ${record.remarks}'),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Employees in this DTR',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: record.employees.isEmpty
                          ? const Center(
                              child: Text(
                                'This DTR does not include employees.',
                              ),
                            )
                          : Card(
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('No.')),
                                      DataColumn(
                                        label: Text('Employee number'),
                                      ),
                                      DataColumn(label: Text('Employee name')),
                                      DataColumn(label: Text('Designation')),
                                      DataColumn(label: Text('Days attended')),
                                      DataColumn(label: Text('Late days')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('')),
                                    ],
                                    rows: [
                                      for (
                                        var index = 0;
                                        index < record.employees.length;
                                        index++
                                      )
                                        _employeeRow(
                                          context,
                                          index + 1,
                                          record.employees[index],
                                          record.code,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  DataRow _employeeRow(
    BuildContext context,
    int number,
    DtrEmployeeRecord employee,
    String batchCode,
  ) {
    final attended = employee.entries
        .where((entry) => entry.status == 'present' || entry.status == 'late')
        .length;
    final late = employee.entries
        .where((entry) => entry.status == 'late')
        .length;

    return DataRow(
      cells: [
        DataCell(Text('$number')),
        DataCell(Text(employee.employeeNo)),
        DataCell(Text(employee.name)),
        DataCell(Text(employee.designation ?? '—')),
        DataCell(Text('$attended')),
        DataCell(Text('$late')),
        const DataCell(_DtrStatusChip()),
        DataCell(
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  _EmployeeDtrDialog(batchCode: batchCode, employee: employee),
            ),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('View'),
          ),
        ),
      ],
    );
  }
}

class _DtrMetadata extends StatelessWidget {
  const _DtrMetadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DtrStatusChip extends StatelessWidget {
  const _DtrStatusChip();

  @override
  Widget build(BuildContext context) {
    final color = Colors.orange;
    return Chip(
      label: const Text('Generated'),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmployeeDtrDialog extends StatelessWidget {
  const _EmployeeDtrDialog({required this.batchCode, required this.employee});

  final String batchCode;
  final DtrEmployeeRecord employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 760),
        child: SizedBox(
          width: 1100,
          height: 700,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Employee daily time record',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$batchCode · ${employee.employeeNo} · ${employee.name}'
                            '${employee.designation == null ? '' : ' · ${employee.designation}'}',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _legendDot(context, 'Present', Colors.green),
                    _legendDot(context, 'Late', Colors.orange),
                    _legendDot(context, 'Absent', theme.colorScheme.error),
                    _legendDot(context, 'On leave', Colors.teal),
                    _legendDot(context, 'Day off', theme.colorScheme.outline),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Day')),
                            DataColumn(label: Text('AM In')),
                            DataColumn(label: Text('AM Out')),
                            DataColumn(label: Text('PM In')),
                            DataColumn(label: Text('PM Out')),
                            DataColumn(label: Text('OT In')),
                            DataColumn(label: Text('OT Out')),
                            DataColumn(label: Text('Attendance')),
                            DataColumn(label: Text('Hours worked')),
                          ],
                          rows: [
                            for (
                              var index = 0;
                              index < employee.entries.length;
                              index++
                            )
                              _entryRow(index + 1, employee.entries[index]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  DataRow _entryRow(int index, DtrEntry entry) => DataRow(
    cells: [
      DataCell(Text('$index')),
      DataCell(Text(shortDate(entry.date))),
      DataCell(Text(_weekday(entry.date.weekday))),
      DataCell(Text(entry.timeLabelFor(entry.amInAt))),
      DataCell(Text(entry.timeLabelFor(entry.amOutAt))),
      DataCell(Text(entry.timeLabelFor(entry.pmInAt))),
      DataCell(Text(entry.timeLabelFor(entry.pmOutAt))),
      DataCell(Text(entry.timeLabelFor(entry.otInAt))),
      DataCell(Text(entry.timeLabelFor(entry.otOutAt))),
      DataCell(_entryStatus(entry.status)),
      DataCell(Text(entry.workedTimeLabel)),
    ],
  );

  Widget _entryStatus(String status) {
    final color = switch (status) {
      'present' => Colors.green,
      'late' => Colors.orange,
      'absent' => Colors.red,
      'on_leave' => Colors.teal,
      'day_off' => Colors.blue,
      _ => Colors.grey,
    };
    return Text(
      attendanceStatusLabel(status),
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  String _weekday(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];
}
