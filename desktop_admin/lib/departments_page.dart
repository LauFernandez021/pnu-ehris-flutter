import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class DepartmentsPage extends ConsumerWidget {
  const DepartmentsPage({super.key});

  Future<String?> _nameDialog(
    BuildContext context, {
    Department? department,
  }) async {
    final controller = TextEditingController(text: department?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(department == null ? 'Add department' : 'Edit department'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Department name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a department name.'
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref, {
    Department? department,
  }) async {
    final name = await _nameDialog(context, department: department);
    if (name == null || !context.mounted) return;
    try {
      final service = DepartmentService(ref.read(apiClientProvider));
      if (department == null) {
        await service.create(name);
      } else {
        await service.update(department.id, name);
      }
      if (!context.mounted) return;
      ref.invalidate(departmentsProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Department saved.')));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Department department,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive department?'),
        content: Text(
          'Departments assigned to any employee record cannot be archived. ${department.name} can be restored later.',
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
      await DepartmentService(ref.read(apiClientProvider))
          .archive(department.id);
      if (!context.mounted) return;
      ref.invalidate(departmentsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${department.name} archived.')));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Departments', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Manage organizational departments. Referenced departments are protected from archiving.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _save(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add department'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: departments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load departments: $error'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(departmentsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No departments have been added.'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final department = items[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.apartment_outlined),
                            ),
                            title: Text(department.name),
                            subtitle: Text('Department #${department.id}'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _save(
                                    context,
                                    ref,
                                    department: department,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Archive',
                                  onPressed: () =>
                                      _archive(context, ref, department),
                                  icon: const Icon(Icons.archive_outlined),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
