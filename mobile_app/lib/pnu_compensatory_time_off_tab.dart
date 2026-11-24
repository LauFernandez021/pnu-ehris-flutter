import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'pnu_api.dart';
import 'providers.dart';

class PnuCompensatoryTimeOffTab extends ConsumerWidget {
  const PnuCompensatoryTimeOffTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(pnuCompensatoryTimeOffProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pnuCompensatoryTimeOffProvider);
        await ref.read(pnuCompensatoryTimeOffProvider.future);
      },
      child: summary.when(
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
            Text('Could not load your COC requests: $error'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => ref.invalidate(pnuCompensatoryTimeOffProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
        data: (data) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Available COC balance'),
                trailing: Text(data.availableBalance.toStringAsFixed(3)),
              ),
            ),
            if (data.requests.isEmpty) ...[
              const SizedBox(height: 100),
              const Icon(Icons.inbox_outlined, size: 52),
              const SizedBox(height: 12),
              const Center(
                child: Text('No compensatory time-off requests yet.'),
              ),
            ] else ...[
              for (final request in data.requests) ...[
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(request.controlNumber),
                    subtitle: Text(
                      '${shortDate(request.periodFrom)} - ${shortDate(request.periodTo)}\n'
                      '${request.hours} hours · balance after: '
                      '${request.balanceAfter.toStringAsFixed(3)}',
                    ),
                    isThreeLine: true,
                    trailing: _CtoStatusChip(status: request.status),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CtoStatusChip extends StatelessWidget {
  const _CtoStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(status.replaceAll('_', ' ')),
    visualDensity: VisualDensity.compact,
  );
}

Future<bool?> openPnuCtoForm(BuildContext context) => Navigator.of(context)
    .push<bool>(
      MaterialPageRoute(builder: (_) => const PnuCompensatoryTimeOffPage()),
    );

class PnuCompensatoryTimeOffPage extends ConsumerStatefulWidget {
  const PnuCompensatoryTimeOffPage({super.key});

  @override
  ConsumerState<PnuCompensatoryTimeOffPage> createState() =>
      _PnuCompensatoryTimeOffPageState();
}

class _PnuCompensatoryTimeOffPageState
    extends ConsumerState<PnuCompensatoryTimeOffPage> {
  static const _hourOptions = [4, 8, 12, 16, 24, 32, 40];

  final DateTime _tomorrow = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  late DateTime _periodFrom = _tomorrow;
  late DateTime _periodTo = _tomorrow;
  int _hours = 4;
  bool _saving = false;
  String? _error;

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _periodFrom : _periodTo;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.isBefore(_tomorrow) ? _tomorrow : current,
      firstDate: _tomorrow,
      lastDate: isStart
          ? DateTime(DateTime.now().year + 2, 12, 31)
          : _periodFrom.add(const Duration(days: 127)),
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _periodFrom = selected;
        if (_periodTo.isBefore(selected)) _periodTo = selected;
        if (_periodTo.difference(selected).inDays > 127) {
          _periodTo = selected.add(const Duration(days: 127));
        }
      } else {
        _periodTo = selected;
      }
    });
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _submit(double? availableBalance) async {
    if (_periodFrom.isBefore(_tomorrow) ||
        _periodTo.isBefore(_periodFrom) ||
        (availableBalance != null && _hours > availableBalance)) {
      setState(() {
        _error =
            'Choose dates no more than 127 days apart and an amount within your available COC balance.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PnuAuthService(ref.read(apiClientProvider))
          .submitCompensatoryTimeOff({
            'period_from': _dateString(_periodFrom),
            'period_to': _dateString(_periodTo),
            'no_of_hours': _hours,
          });
      ref.invalidate(pnuCompensatoryTimeOffProvider);
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
    final balance = ref
        .watch(pnuCompensatoryTimeOffProvider)
        .maybeWhen(
          data: (summary) => summary.availableBalance,
          orElse: () => null,
        );
    return Scaffold(
      appBar: AppBar(title: const Text('New Compensatory Time-Off')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickDate(isStart: true),
            icon: const Icon(Icons.event_outlined),
            label: Text('Period from: ${shortDate(_periodFrom)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickDate(isStart: false),
            icon: const Icon(Icons.event_outlined),
            label: Text('Period to: ${shortDate(_periodTo)}'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _hours,
            decoration: const InputDecoration(labelText: 'COC hours to use'),
            items: [
              for (final hours in _hourOptions)
                DropdownMenuItem(value: hours, child: Text('$hours hours')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _hours = value);
                  },
          ),
          if (balance != null) ...[
            const SizedBox(height: 12),
            Text('Available balance: ${balance.toStringAsFixed(3)} hours'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : () => _submit(balance),
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
