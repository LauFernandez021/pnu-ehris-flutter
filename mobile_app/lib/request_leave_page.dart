import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:image_picker/image_picker.dart';

import 'providers.dart';

Future<void> openRequestForm(BuildContext context) async {
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const RequestLeavePage()),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave request submitted')),
    );
  }
}

class RequestLeavePage extends ConsumerStatefulWidget {
  const RequestLeavePage({super.key});

  @override
  ConsumerState<RequestLeavePage> createState() => _RequestLeavePageState();
}

class _RequestLeavePageState extends ConsumerState<RequestLeavePage> {
  final _reason = TextEditingController();
  int? _typeId;
  DateTimeRange? _range;
  Uint8List? _proof;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _pickProof(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _proof = bytes);
  }

  Future<void> _submit({required bool proofRequired}) async {
    if (_typeId == null || _range == null) {
      setState(() => _error = 'Choose a leave type and the dates.');
      return;
    }
    if (proofRequired && _proof == null) {
      setState(() => _error = 'Please attach your medical certificate or proof.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LeaveService(ref.read(apiClientProvider)).submit(
        leaveTypeId: _typeId!,
        start: _range!.start,
        end: _range!.end,
        reason: _reason.text,
        attachment: _proof,
      );
      ref.invalidate(myRequestsProvider);
      ref.invalidate(balancesProvider);
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
    final balances = ref.watch(balancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request leave')),
      body: balances.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          LeaveBalance? selected;
          for (final b in list) {
            if (b.leaveTypeId == _typeId) selected = b;
          }
          final days =
              _range == null ? 0 : workingDays(_range!.start, _range!.end);
          final tooMany = selected != null && days > selected.available;
          final from = selected?.attachmentFromDays;
          final proofRequired = from != null && days >= from;

          return ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<int>(
              initialValue: _typeId,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: [
                for (final b in list)
                  DropdownMenuItem(
                    value: b.leaveTypeId,
                    child: Text('${b.leaveType} (${dayLabel(b.available)} available)'),
                  ),
              ],
              onChanged: (v) => setState(() {
                _typeId = v;
                _proof = null;
              }),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.date_range),
              label: Text(_range == null
                  ? 'Select dates'
                  : '${shortDate(_range!.start)} – ${shortDate(_range!.end)}'),
              onPressed: _pickRange,
            ),
            if (_range != null) ...[
              const SizedBox(height: 8),
              Text(
                days == 0
                    ? 'These dates have no working days (weekends are not counted).'
                    : '$days working ${days == 1 ? 'day' : 'days'}',
                style: TextStyle(
                  color: (tooMany || days == 0)
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (tooMany)
                Text('More than your available balance.',
                    style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (from != null) ...[
              const SizedBox(height: 20),
              Text(
                proofRequired
                    ? 'Medical certificate or proof (required)'
                    : 'Medical certificate or proof (optional)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Required for ${selected!.leaveType} of $from or more working days.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              if (_proof != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_proof!,
                        height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(_proof == null ? 'Take photo' : 'Retake'),
                    onPressed: () => _pickProof(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose'),
                    onPressed: () => _pickProof(ImageSource.gallery),
                  ),
                ),
              ]),
              if (_proof != null)
                TextButton(
                  onPressed: () => setState(() => _proof = null),
                  child: const Text('Remove attachment'),
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_saving || tooMany || (_range != null && days == 0))
                  ? null
                  : () => _submit(proofRequired: proofRequired),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit request'),
            ),
          ]);
        },
      ),
    );
  }
}