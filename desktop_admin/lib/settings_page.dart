import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _showArchived = false;
  bool _saving = false;
  bool _changingPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _passwordError;
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(leaveTypesProvider(_showArchived));

  Future<void> _editType({LeaveType? type}) async {
    final name = TextEditingController(text: type?.name ?? '');
    final days = TextEditingController(
      text: type?.daysPerYear.toString() ?? '0',
    );
    final attachmentDays = TextEditingController(
      text: type?.attachmentRequiredFromDays?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final input = await showDialog<_LeaveTypeInput>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == null ? 'Add leave type' : 'Edit leave type'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a leave type name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Days per year'),
                  validator: (value) => _validateInteger(value, max: 365),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: attachmentDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Proof required from (days)',
                    helperText: 'Leave blank when proof is not required.',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? null
                      : _validateInteger(value, max: 365),
                ),
              ],
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
              Navigator.pop(
                context,
                _LeaveTypeInput(
                  name: name.text.trim(),
                  daysPerYear: int.parse(days.text.trim()),
                  attachmentRequiredFromDays: attachmentDays.text.trim().isEmpty
                      ? null
                      : int.parse(attachmentDays.text.trim()),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    days.dispose();
    attachmentDays.dispose();
    if (input == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final service = LeaveTypeService(ref.read(apiClientProvider));
      if (type == null) {
        await service.create(
          name: input.name,
          daysPerYear: input.daysPerYear,
          attachmentRequiredFromDays: input.attachmentRequiredFromDays,
        );
      } else {
        await service.updateType(
          id: type.id,
          name: input.name,
          daysPerYear: input.daysPerYear,
          attachmentRequiredFromDays: input.attachmentRequiredFromDays,
        );
      }
      if (!mounted) return;
      ref.invalidate(leaveTypesProvider(false));
      _showMessage('Leave type saved.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive(LeaveType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive leave type?'),
        content: Text(
          '${type.name} will no longer be available for new leave requests. '
          'Types with balances or request history are protected.',
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
      await LeaveTypeService(ref.read(apiClientProvider)).archive(type.id);
      if (!mounted) return;
      ref.invalidate(leaveTypesProvider(false));
      _showMessage('Leave type archived.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _restore(LeaveType type) async {
    try {
      await LeaveTypeService(ref.read(apiClientProvider)).restore(type.id);
      if (!mounted) return;
      ref.invalidate(leaveTypesProvider(true));
      _showMessage('Leave type restored.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePassword(StateSetter setDialogState) async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setDialogState(() {
      _changingPassword = true;
      _passwordError = null;
    });
    try {
      await AuthService(ref.read(apiClientProvider)).changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      await ref.read(sessionProvider.notifier).markPasswordChanged();
      if (!mounted) return;
      _changingPassword = false;
      Navigator.of(context).pop();
      _showMessage('Your password has been changed.');
    } on ApiException catch (error) {
      if (!mounted) return;
      setDialogState(() {
        _changingPassword = false;
        _passwordError = error.message;
      });
    }
  }

  Future<void> _openPasswordDialog() async {
    _currentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    _passwordError = null;
    _showCurrentPassword = false;
    _showNewPassword = false;
    _showConfirmPassword = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: _passwordFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your current password, then choose a new one. '
                      'This device stays signed in; other sessions are signed out.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _currentPassword,
                      autofocus: true,
                      obscureText: !_showCurrentPassword,
                      enabled: !_changingPassword,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showCurrentPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setDialogState(
                            () => _showCurrentPassword = !_showCurrentPassword,
                          ),
                          icon: Icon(
                            _showCurrentPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your current password.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPassword,
                      obscureText: !_showNewPassword,
                      enabled: !_changingPassword,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          tooltip: _showNewPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setDialogState(
                            () => _showNewPassword = !_showNewPassword,
                          ),
                          icon: Icon(
                            _showNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: _validateNewPassword,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use at least 10 characters, with an uppercase letter, '
                      'a lowercase letter, and a number.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: !_showConfirmPassword,
                      enabled: !_changingPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          tooltip: _showConfirmPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setDialogState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          ),
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value != _newPassword.text
                          ? 'These passwords do not match.'
                          : null,
                    ),
                    if (_passwordError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _passwordError!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _changingPassword
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _changingPassword
                  ? null
                  : () => _changePassword(setDialogState),
              icon: _changingPassword
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset),
              label: Text(
                _changingPassword ? 'Changing...' : 'Update password',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.length < 10 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Use 10+ characters with uppercase, lowercase, and a number.';
    }
    return null;
  }

  String? _validateInteger(String? value, {required int max}) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0 || parsed > max) {
      return 'Enter a whole number from 0 to $max.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final leaveTypes = ref.watch(leaveTypesProvider(_showArchived));
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
                    Text('Settings', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Manage leave allowances and supporting-document rules.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (!_showArchived)
                FilledButton.icon(
                  onPressed: _saving ? null : () => _editType(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add leave type'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    child: const Icon(Icons.shield_outlined),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account security',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update your password to keep your account secure.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _openPasswordDialog,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Change password'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Leave types', style: theme.textTheme.titleLarge),
              const Spacer(),
              FilterChip(
                selected: _showArchived,
                label: const Text('Archived'),
                onSelected: (value) => setState(() => _showArchived = value),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: leaveTypes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load leave types: $error'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(
                        _showArchived
                            ? 'No archived leave types.'
                            : 'No leave types have been added.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final type = items[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                _showArchived
                                    ? Icons.inventory_2_outlined
                                    : Icons.event_available_outlined,
                              ),
                            ),
                            title: Text(type.name),
                            subtitle: Text(
                              '${type.daysPerYear} days per year'
                              '${type.attachmentRequiredFromDays == null ? '' : ' • Proof from ${type.attachmentRequiredFromDays} day(s)'}',
                            ),
                            trailing: _showArchived
                                ? TextButton.icon(
                                    onPressed: () => _restore(type),
                                    icon: const Icon(Icons.restore),
                                    label: const Text('Restore'),
                                  )
                                : Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: _saving
                                            ? null
                                            : () => _editType(type: type),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Archive',
                                        onPressed: () => _archive(type),
                                        icon: const Icon(
                                          Icons.archive_outlined,
                                        ),
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

class _LeaveTypeInput {
  const _LeaveTypeInput({
    required this.name,
    required this.daysPerYear,
    required this.attachmentRequiredFromDays,
  });

  final String name;
  final int daysPerYear;
  final int? attachmentRequiredFromDays;
}
