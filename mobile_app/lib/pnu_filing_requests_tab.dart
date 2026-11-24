import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'pnu_api.dart';
import 'providers.dart';

class PnuFilingRequestsTab extends ConsumerWidget {
  const PnuFilingRequestsTab({required this.requestType, super.key});

  final String requestType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pnuFilingRequestsProvider);
    final title = _filingRequestLabels[requestType]!;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pnuFilingRequestsProvider);
        await ref.read(pnuFilingRequestsProvider.future);
      },
      child: requests.when(
        loading: () => ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 220),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text('Could not load your requests: $error'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => ref.invalidate(pnuFilingRequestsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (allRequests) {
          final list = allRequests
              .where((request) => request.type == requestType)
              .toList(growable: false);
          return list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 150),
                    const Center(child: Icon(Icons.inbox_outlined, size: 52)),
                    SizedBox(height: 12),
                    Center(child: Text('No $title requests yet.')),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final request = list[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(title),
                        subtitle: Text(
                          '${shortDate(request.workDate)} · ${request.reason}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _StatusChip(status: request.status),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(status.replaceAll('_', ' ')),
    visualDensity: VisualDensity.compact,
  );
}

const _filingRequestLabels = {
  'overtime': 'Overtime',
  'shift_change': 'Change Shift',
  'dtr_correction': 'DTR Correction',
  'manual_dtr': 'Manual DTR Submission',
};

Future<bool?> openPnuFilingRequestForm(
  BuildContext context, {
  required String requestType,
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => PnuFilingRequestPage(requestType: requestType),
  ),
);

class PnuFilingRequestPage extends ConsumerStatefulWidget {
  const PnuFilingRequestPage({required this.requestType, super.key});

  final String requestType;

  @override
  ConsumerState<PnuFilingRequestPage> createState() =>
      _PnuFilingRequestPageState();
}

class _PnuFilingRequestPageState extends ConsumerState<PnuFilingRequestPage> {
  final _reason = TextEditingController();
  final Map<String, TimeOfDay?> _times = {
    for (final field in [
      'ot_in',
      'ot_out',
      'current_schedule',
      'requested_schedule',
      'am_in',
      'am_out',
      'pm_in',
      'pm_out',
      'corrected_am_in',
      'corrected_am_out',
      'corrected_pm_in',
      'corrected_pm_out',
    ])
      field: null,
  };
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickTime(String field) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[field] ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _times[field] = picked);
  }

  String _dateString() =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  String? _timeValue(String field) {
    final time = _times[field];
    return time == null ? null : hhmm(time.hour, time.minute);
  }

  Map<String, dynamic> _requestData() {
    final data = <String, dynamic>{
      'request_type': widget.requestType,
      'work_date': _dateString(),
      'reason': _reason.text.trim(),
    };
    if (widget.requestType == 'overtime') {
      data['ot_in'] = _timeValue('ot_in');
      data['ot_out'] = _timeValue('ot_out');
    } else if (widget.requestType == 'shift_change') {
      data['current_schedule'] = _timeValue('current_schedule');
      data['requested_schedule'] = _timeValue('requested_schedule');
    } else if (widget.requestType == 'dtr_correction') {
      for (final key in [
        'corrected_am_in',
        'corrected_am_out',
        'corrected_pm_in',
        'corrected_pm_out',
      ]) {
        final value = _timeValue(key);
        if (value != null) data[key] = value;
      }
    } else {
      for (final key in ['am_in', 'am_out', 'pm_in', 'pm_out']) {
        final value = _timeValue(key);
        if (value != null) data[key] = value;
      }
    }
    return data;
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Enter a reason for this request.');
      return;
    }
    if (widget.requestType == 'shift_change' &&
        _times['requested_schedule'] == null) {
      setState(() => _error = 'Choose the requested schedule time.');
      return;
    }
    if (widget.requestType == 'overtime' &&
        (_times['ot_in'] == null || _times['ot_out'] == null)) {
      setState(() => _error = 'Choose the overtime start and end times.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PnuAuthService(ref.read(apiClientProvider))
          .submitFilingRequest(_requestData());
      ref.invalidate(pnuFilingRequestsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _filingRequestLabels[widget.requestType]!;
    return Scaffold(
      appBar: AppBar(title: Text('New $title request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(shortDate(_date)),
          ),
          if (widget.requestType == 'overtime') ...[
            _timeField('ot_in', 'Overtime start'),
            _timeField('ot_out', 'Overtime end'),
          ] else if (widget.requestType == 'shift_change') ...[
            _timeField('current_schedule', 'Current schedule (optional)'),
            _timeField('requested_schedule', 'Requested schedule'),
          ] else if (widget.requestType == 'dtr_correction') ...[
            _timeField('corrected_am_in', 'Corrected AM in'),
            _timeField('corrected_am_out', 'Corrected AM out'),
            _timeField('corrected_pm_in', 'Corrected PM in'),
            _timeField('corrected_pm_out', 'Corrected PM out'),
          ] else ...[
            _timeField('am_in', 'AM in'),
            _timeField('am_out', 'AM out'),
            _timeField('pm_in', 'PM in'),
            _timeField('pm_out', 'PM out'),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit request'),
          ),
        ],
      ),
    );
  }

  Widget _timeField(String key, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: OutlinedButton.icon(
      onPressed: () => _pickTime(key),
      icon: const Icon(Icons.schedule_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _times[key] == null
              ? label
              : '$label: ${_times[key]!.format(context)}',
          textAlign: TextAlign.left,
        ),
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );
}
