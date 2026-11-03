import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'employee_form_dialog.dart';
import 'providers.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  String _query = '';

  Future<void> _openForm({Employee? employee}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EmployeeFormDialog(employee: employee),
    );
    if (saved == true) {
      ref.invalidate(employeesProvider);
      ref.invalidate(summaryProvider);
    }
  }

  bool _canEdit(Employee e) {
    final mine = ref.read(sessionProvider)?.roles ?? const <String>[];
    if (mine.contains('admin')) return true;
    return e.role != 'admin' && e.role != 'hr';
  }

  Future<void> _printBadge(Employee employee) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          85.6 * PdfPageFormat.mm,
          54 * PdfPageFormat.mm,
          marginAll: 0,
        ),
        build: (_) => pw.Container(
          margin: pw.EdgeInsets.all(3 * PdfPageFormat.mm),
          padding: pw.EdgeInsets.all(3 * PdfPageFormat.mm),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey700, width: 1.2),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HRMS EMPLOYEE BADGE',
                style: pw.TextStyle(
                  color: PdfColors.blueGrey700,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                employee.fullName,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Employee no. ${employee.employeeNo}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                employee.badgeNumber ?? employee.employeeNo,
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Printable HRMS badge number - not an RFID UID',
                style: const pw.TextStyle(fontSize: 6),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await Printing.layoutPdf(
        name: 'Employee badge ${employee.badgeNumber ?? employee.employeeNo}',
        onLayout: (_) async => pdf.save(),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not print employee badge: $error')),
      );
    }
  }

  Future<void> _archiveEmployee(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive employee?'),
        content: Text(
          '${employee.fullName} will lose access. Attendance and DTR history will be retained.',
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
      await EmployeeService(ref.read(apiClientProvider)).archive(employee.id);
      if (!mounted) return;
      ref.invalidate(employeesProvider);
      ref.invalidate(summaryProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${employee.fullName} archived.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employees = ref.watch(employeesProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Employees',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name, number, email, department',
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(employeesProvider),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Add employee'),
                onPressed: () => _openForm(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: employees.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (all) {
                final list = _query.isEmpty
                    ? all
                    : all
                          .where(
                            (e) =>
                                '${e.fullName} ${e.employeeNo} ${e.email ?? ''} ${e.department ?? ''}'
                                    .toLowerCase()
                                    .contains(_query),
                          )
                          .toList();

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          all.isEmpty
                              ? 'No employees yet. Add your first one.'
                              : 'No one matches your search.',
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
                          DataColumn(label: Text('Employee')),
                          DataColumn(label: Text('No.')),
                          DataColumn(label: Text('Badge number')),
                          DataColumn(label: Text('RFID')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Department')),
                          DataColumn(label: Text('Position')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [
                          for (final e in list)
                            DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      InitialsAvatar(e.fullName),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.fullName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              e.email ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(e.employeeNo)),
                                DataCell(Text(e.badgeNumber ?? '—')),
                                DataCell(
                                  Tooltip(
                                    message: e.rfidCardNumber == null
                                        ? 'No card credential linked'
                                        : 'Card credential linked',
                                    child: Icon(
                                      e.rfidCardNumber == null
                                          ? Icons.credit_card_off_outlined
                                          : Icons.credit_card,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                DataCell(Text(e.role ?? '-')),
                                DataCell(Text(e.department ?? '-')),
                                DataCell(Text(e.position ?? '-')),
                                DataCell(StatusChip(e.status)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Print badge',
                                        icon: const Icon(Icons.print_outlined),
                                        onPressed: () => _printBadge(e),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: _canEdit(e)
                                            ? () => _openForm(employee: e)
                                            : null,
                                      ),
                                      if (_canEdit(e))
                                        IconButton(
                                          tooltip: 'Archive',
                                          icon: const Icon(
                                            Icons.archive_outlined,
                                          ),
                                          onPressed: () => _archiveEmployee(e),
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
