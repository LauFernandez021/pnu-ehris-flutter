import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

class EmployeeFormDialog extends ConsumerStatefulWidget {
  const EmployeeFormDialog({super.key, this.employee});

  /// null = add a new employee, otherwise edit this one.
  final Employee? employee;

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _employeeNo;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _position;
  late final TextEditingController _deviceId;
  late final TextEditingController _rfidCardNumber;
  final _password = TextEditingController();

  late String _role;
  late String _status;
  int? _departmentId;
  DateTime? _dateHired;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.employee != null;
  bool get _statusLocked =>
      _isEdit && !{'active', 'inactive'}.contains(widget.employee!.status);

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _employeeNo = TextEditingController(text: e?.employeeNo ?? '');
    _firstName = TextEditingController(text: e?.firstName ?? '');
    _lastName = TextEditingController(text: e?.lastName ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _position = TextEditingController(text: e?.position ?? '');
    _deviceId = TextEditingController(text: e?.deviceUserId ?? '');
    _rfidCardNumber = TextEditingController(text: e?.rfidCardNumber ?? '');
    _role = e?.role ?? 'employee';
    _status = e?.status ?? 'active';
    _departmentId = e?.departmentId;
    _dateHired = DateTime.tryParse(e?.dateHired ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _employeeNo,
      _firstName,
      _lastName,
      _email,
      _position,
      _deviceId,
      _rfidCardNumber,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _dateText() => _dateHired?.toIso8601String().split('T').first;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateHired ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dateHired = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final service = EmployeeService(ref.read(apiClientProvider));
    String? blankToNull(String s) => s.trim().isEmpty ? null : s.trim();

    try {
      if (_isEdit) {
        await service.update(widget.employee!.id, {
          'employee_no': _employeeNo.text.trim(),
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'email': _email.text.trim(),
          'role': _role,
          if (!_statusLocked) 'status': _status,
          'department_id': _departmentId,
          'position': blankToNull(_position.text),
          'date_hired': _dateText(),

          'device_user_id': blankToNull(_deviceId.text),
          'rfid_card_number': blankToNull(_rfidCardNumber.text),
          if (_password.text.isNotEmpty) 'new_password': _password.text,
        });
      } else {
        await service.create(
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
          employeeNo: _employeeNo.text.trim(),
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          departmentId: _departmentId,
          position: _position.text.trim(),
          dateHired: _dateHired,
          deviceUserId: _deviceId.text.trim(),
          rfidCardNumber: _rfidCardNumber.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myRoles = ref.watch(sessionProvider)?.roles ?? const <String>[];
    final base = myRoles.contains('admin')
        ? ['employee', 'manager', 'hr', 'admin']
        : ['employee', 'manager'];
    final roleOptions = {
      ...base,
      _role,
    }.toList(); // never drop the current role
    final departments = ref.watch(departmentsProvider);

    const gap = SizedBox(height: 18);
    const hGap = SizedBox(width: 16);
    final sectionStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    return AlertDialog(
      title: Text(_isEdit ? 'Edit employee' : 'Add employee'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Account', style: sectionStyle),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _employeeNo,
                        decoration: const InputDecoration(
                          labelText: 'Employee no.',
                        ),
                        validator: _required,
                      ),
                    ),
                    hGap,
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: [
                          for (final r in roleOptions)
                            DropdownMenuItem(value: r, child: Text(r)),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? _role),
                      ),
                    ),
                  ],
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        validator: _required,
                      ),
                    ),
                    hGap,
                    Expanded(
                      child: TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                gap,
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email (login)'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                gap,
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: _isEdit
                        ? 'New password (leave blank to keep current)'
                        : 'Temporary password',
                    helperText: 'At least 10 characters, including uppercase, lowercase, and a number.',
                  ),
                  obscureText: true,
                  validator: (v) {
                    final value = v ?? '';
                    if (_isEdit && value.isEmpty) return null;
                    return value.length < 10 ||
                            !RegExp(r'[A-Z]').hasMatch(value) ||
                            !RegExp(r'[a-z]').hasMatch(value) ||
                            !RegExp(r'[0-9]').hasMatch(value)
                        ? 'Use at least 10 characters with uppercase, lowercase, and a number'
                        : null;
                  },
                ),
                const SizedBox(height: 28),
                Text('Job details', style: sectionStyle),
                gap,
                departments.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load departments: $e'),
                  data: (list) => DropdownButtonFormField<int?>(
                    initialValue: _departmentId,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      for (final d in list)
                        DropdownMenuItem<int?>(
                          value: d.id,
                          child: Text(d.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                ),
                gap,
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _dateHired == null
                        ? 'Set hire date'
                        : 'Hire date · ${shortDate(_dateHired!)}',
                  ),
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _position,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                        ),
                      ),
                    ),
                    hGap,
                    Expanded(
                      child: TextFormField(
                        controller: _deviceId,
                        decoration: const InputDecoration(
                          labelText: 'Biometric device ID',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isEdit && widget.employee!.badgeNumber != null) ...[
                  gap,
                  TextFormField(
                    initialValue: widget.employee!.badgeNumber,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Printable badge number',
                      helperText: 'HRMS badge number only; it is not the RFID card UID.',
                    ),
                  ),
                ] else ...[
                  gap,
                  const Text(
                    'A printable HRMS badge number will be assigned after saving.',
                  ),
                ],
                gap,
                TextFormField(
                  controller: _rfidCardNumber,
                  decoration: const InputDecoration(
                    labelText: 'RFID card credential',
                    helperText: 'Enter the actual card value read by a compatible reader. This does not write or enroll the card on a ZKTeco terminal.',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                if (_error != null) ...[
                  gap,
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (_isEdit) ...[
                  gap,
                  if (_statusLocked)
                    Row(
                      children: [
                        StatusChip(widget.employee!.status),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Approve or reject this account from Account approvals.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('active'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('inactive'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save changes' : 'Save'),
        ),
      ],
    );
  }
}
