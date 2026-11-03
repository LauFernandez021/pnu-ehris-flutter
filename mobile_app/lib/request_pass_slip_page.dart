import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

Future<void> openPassSlipForm(BuildContext context) async {
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const RequestPassSlipPage()),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pass slip submitted')),
    );
  }
}

class RequestPassSlipPage extends ConsumerStatefulWidget {
  const RequestPassSlipPage({super.key});

  @override
  ConsumerState<RequestPassSlipPage> createState() =>
      _RequestPassSlipPageState();
}

class _RequestPassSlipPageState extends ConsumerState<RequestPassSlipPage> {
  final _destination = TextEditingController();
  final _reason = TextEditingController();
  String _type = 'personal';
  DateTime _date = DateTime.now();
  TimeOfDay? _out;
  TimeOfDay? _in;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _destination.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isOut}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isOut ? _out : _in) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => isOut ? _out = picked : _in = picked);
  }

  Future<void> _submit() async {
    if (_out == null || _in == null || _destination.text.trim().isEmpty) {
      setState(() => _error = 'Fill in the times and where you are going.');
      return;
    }
    final outMin = _out!.hour * 60 + _out!.minute;
    final inMin = _in!.hour * 60 + _in!.minute;
    if (inMin <= outMin) {
      setState(() => _error = 'Return time must be after the time out.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PassSlipService(ref.read(apiClientProvider)).submit(
        slipType: _type,
        date: _date,
        timeOut: hhmm(_out!.hour, _out!.minute),
        timeIn: hhmm(_in!.hour, _in!.minute),
        destination: _destination.text,
        reason: _reason.text,
      );
      ref.invalidate(myPassSlipsProvider);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Pass slip')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'personal', label: Text('Personal')),
            ButtonSegment(value: 'official', label: Text('Official business')),
          ],
          selected: {_type},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: const Icon(Icons.event),
          label: Text(shortDate(_date)),
          onPressed: _pickDate,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.logout),
              label: Text(_out == null ? 'Time out' : _out!.format(context)),
              onPressed: () => _pickTime(isOut: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.login),
              label: Text(_in == null ? 'Back by' : _in!.format(context)),
              onPressed: () => _pickTime(isOut: false),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _destination,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Where are you going?'),
        ),
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
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit pass slip'),
        ),
      ]),
    );
  }
}