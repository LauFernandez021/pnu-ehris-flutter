import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'pnu_api.dart';
import 'providers.dart';

class PnuServiceRequestsTab extends ConsumerWidget {
  const PnuServiceRequestsTab({required this.requestType, super.key});

  final String requestType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pnuServiceRequestsProvider);
    final title = requestType == 'vehicle' ? 'Vehicle request' : 'Locator slip';
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pnuServiceRequestsProvider);
        await ref.read(pnuServiceRequestsProvider.future);
      },
      child: requests.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
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
            Text('Could not load your $title records: $error'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => ref.invalidate(pnuServiceRequestsProvider),
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
                    Center(child: Text('No $title records yet.')),
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
                        leading: const Icon(Icons.directions_car_outlined),
                        title: Text(request.typeLabel),
                        subtitle: Text(
                          '${request.controlNumber} · ${shortDate(request.dateNeeded)} at '
                          '${request.timeNeeded}\n${request.destination} · ${request.purpose}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: _RequestStatusChip(status: request.status),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}

class _RequestStatusChip extends StatelessWidget {
  const _RequestStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(status.replaceAll('_', ' ')),
    visualDensity: VisualDensity.compact,
  );
}

Future<bool?> openPnuServiceRequestForm(
  BuildContext context, {
  required String requestType,
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => PnuServiceRequestPage(requestType: requestType),
  ),
);

class PnuServiceRequestPage extends ConsumerStatefulWidget {
  const PnuServiceRequestPage({required this.requestType, super.key});

  final String requestType;

  @override
  ConsumerState<PnuServiceRequestPage> createState() =>
      _PnuServiceRequestPageState();
}

class _PnuServiceRequestPageState extends ConsumerState<PnuServiceRequestPage> {
  final _purpose = TextEditingController();
  final _destination = TextEditingController();
  DateTime _dateNeeded = DateTime.now();
  TimeOfDay? _timeNeeded;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _purpose.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateNeeded,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (date != null) setState(() => _dateNeeded = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _timeNeeded ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _timeNeeded = time);
  }

  String _dateString() =>
      '${_dateNeeded.year.toString().padLeft(4, '0')}-'
      '${_dateNeeded.month.toString().padLeft(2, '0')}-'
      '${_dateNeeded.day.toString().padLeft(2, '0')}';

  String _timeString(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_purpose.text.trim().isEmpty ||
        _destination.text.trim().isEmpty ||
        _timeNeeded == null) {
      setState(() {
        _error = 'Enter a purpose and destination, and choose a needed time.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PnuAuthService(ref.read(apiClientProvider)).submitServiceRequest({
        'request_type': widget.requestType,
        'date_needed': _dateString(),
        'time_needed': _timeString(_timeNeeded!),
        'purpose': _purpose.text.trim(),
        'destination': _destination.text.trim(),
      });
      ref.invalidate(pnuServiceRequestsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.requestType == 'vehicle'
        ? 'Vehicle request'
        : 'Locator slip';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('New $title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text('Date needed: ${shortDate(_dateNeeded)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule_outlined),
            label: Text(
              _timeNeeded == null
                  ? 'Choose time needed'
                  : 'Time needed: ${_timeNeeded!.format(context)}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purpose,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Purpose'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Destination'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Submitting...' : 'Submit request'),
          ),
        ],
      ),
    );
  }
}
