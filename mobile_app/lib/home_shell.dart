import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'home_tab.dart';
import 'internet_status_notice.dart';
import 'pnu_api.dart';
import 'pnu_compensatory_time_off_tab.dart';
import 'pnu_dtr_tab.dart';
import 'pnu_filing_requests_tab.dart';
import 'pnu_notifications_tab.dart';
import 'pnu_password_change_page.dart';
import 'pnu_service_requests_tab.dart';
import 'providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  String _module = 'dashboard';

  static const _moduleTitles = {
    'dashboard': 'Dashboard',
    'calendar': 'Calendar',
    'pds': 'P.D.S.',
    'leave_application': 'Leave Application',
    'leave_credits': 'Leave Credits',
    'leave_thresholds': 'Leave Threshold Alerts',
    'leave_coc': 'COC',
    'cto': 'Compensatory Time-Off',
    'overtime': 'Overtime Request',
    'shift_change': 'Change Shift',
    'dtr_correction': 'DTR Correction',
    'manual_dtr': 'Manual DTR Submission',
    'vehicle': 'Vehicle Request',
    'locator': 'Locator Slip',
    'training': 'Training Course',
    'performance': 'Performance Evaluation',
    'job_vacancies': 'Job Vacancies',
    'dtr': 'DTR',
    'payroll': 'Payroll',
    'loans': 'Loan Management',
    'contributions': 'Monthly Contributions',
    'accomplishments': 'Accomplishment Report',
    'service_record': 'Service Record',
    'self_assessment': 'Self-Assessment',
    'memos': 'Memo / Notifications',
  };

  Future<void> _logout() async {
    try {
      await PnuAuthService(ref.read(apiClientProvider)).logout();
    } on ApiException {
      // Sign out locally even if the server can't be reached.
    }
    await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final title = _moduleTitles[_module] ?? 'Settings';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (value) {
              if (value == 'password') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PnuPasswordChangePage(
                      api: ref.read(apiClientProvider),
                      onComplete: () => ref
                          .read(sessionProvider.notifier)
                          .markPasswordChanged(),
                    ),
                  ),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'password',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_outline),
                  title: Text('Change password'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Sign out'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const InternetStatusNotice(),
          Expanded(child: _modulePage()),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ListTile(
                leading: Icon(Icons.badge_outlined),
                title: Text('PNU EHRIS'),
                subtitle: Text('Employee self-service'),
              ),
              const Divider(),
              _destination(context, 'dashboard', Icons.dashboard_outlined),
              _destination(context, 'calendar', Icons.calendar_month_outlined),
              _destination(context, 'pds', Icons.person_outline),
              _group(
                'Leave',
                Icons.groups_outlined,
                initiallyExpanded: _module.startsWith('leave_'),
                children: [
                  _destination(context, 'leave_application', Icons.arrow_right),
                  _destination(context, 'leave_credits', Icons.arrow_right),
                  _destination(
                    context,
                    'leave_thresholds',
                    Icons.warning_amber,
                  ),
                  _destination(context, 'leave_coc', Icons.arrow_right),
                ],
              ),
              _group(
                'Request',
                Icons.folder_copy_outlined,
                initiallyExpanded: const {
                  'cto',
                  'overtime',
                  'shift_change',
                  'dtr_correction',
                  'manual_dtr',
                  'vehicle',
                  'locator',
                }.contains(_module),
                children: [
                  _destination(context, 'cto', Icons.arrow_right),
                  _destination(context, 'overtime', Icons.schedule),
                  _destination(context, 'shift_change', Icons.swap_horiz),
                  _destination(context, 'dtr_correction', Icons.edit_note),
                  _destination(context, 'manual_dtr', Icons.schedule),
                  _destination(
                    context,
                    'vehicle',
                    Icons.directions_car_outlined,
                  ),
                  _destination(context, 'locator', Icons.place_outlined),
                ],
              ),
              _group(
                'L & D',
                Icons.signal_cellular_alt,
                children: [
                  _destination(context, 'training', Icons.arrow_right),
                ],
              ),
              _group(
                'Employee Relation',
                Icons.hub_outlined,
                children: [
                  _destination(context, 'performance', Icons.arrow_right),
                  _destination(context, 'job_vacancies', Icons.work_outline),
                ],
              ),
              _group(
                'Compensation',
                Icons.payments_outlined,
                initiallyExpanded:
                    _module == 'dtr' ||
                    _module == 'payroll' ||
                    _module == 'loans' ||
                    _module == 'contributions',
                children: [
                  _destination(context, 'dtr', Icons.arrow_right),
                  _destination(context, 'payroll', Icons.arrow_right),
                  _destination(context, 'loans', Icons.arrow_right),
                  _destination(context, 'contributions', Icons.arrow_right),
                ],
              ),
              _destination(context, 'accomplishments', Icons.book_outlined),
              _destination(context, 'service_record', Icons.archive_outlined),
              _destination(
                context,
                'self_assessment',
                Icons.description_outlined,
              ),
              _destination(context, 'memos', Icons.campaign_outlined),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => _openPasswordChange(context),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: !_supportsNewRequest
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openNewRequest(context),
              icon: const Icon(Icons.add),
              label: const Text('New request'),
            ),
    );
  }

  bool get _supportsNewRequest => const {
    'overtime',
    'shift_change',
    'dtr_correction',
    'manual_dtr',
    'cto',
    'vehicle',
    'locator',
  }.contains(_module);

  Widget _modulePage() {
    if (_module == 'dashboard') return const HomeTab();
    if (_module == 'dtr') return const PnuDtrTab();
    if (_module == 'memos') return const PnuNotificationsTab();
    if (_module == 'cto') return const PnuCompensatoryTimeOffTab();
    if (const {
      'overtime',
      'shift_change',
      'dtr_correction',
      'manual_dtr',
    }.contains(_module)) {
      return PnuFilingRequestsTab(requestType: _module);
    }
    if (_module == 'vehicle' || _module == 'locator') {
      return PnuServiceRequestsTab(requestType: _module);
    }
    return _ComingSoonPage(title: _moduleTitles[_module] ?? 'Settings');
  }

  Widget _destination(BuildContext context, String module, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(_moduleTitles[module]!),
      selected: _module == module,
      onTap: () {
        Navigator.of(context).pop();
        setState(() => _module = module);
      },
    );
  }

  Widget _group(
    String title,
    IconData icon, {
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) => ExpansionTile(
    leading: Icon(icon),
    title: Text(title),
    initiallyExpanded: initiallyExpanded,
    childrenPadding: const EdgeInsets.only(left: 20),
    children: children,
  );

  Future<void> _openNewRequest(BuildContext context) async {
    final submitted = const {
      'overtime',
      'shift_change',
      'dtr_correction',
      'manual_dtr',
    }.contains(_module)
        ? await openPnuFilingRequestForm(context, requestType: _module)
        : _module == 'cto'
        ? await openPnuCtoForm(context)
        : await openPnuServiceRequestForm(context, requestType: _module);
    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request submitted')));
    }
  }

  Future<void> _openPasswordChange(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PnuPasswordChangePage(
          api: ref.read(apiClientProvider),
          onComplete: () =>
              ref.read(sessionProvider.notifier).markPasswordChanged(),
        ),
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_outlined, size: 48),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'This employee self-service module is not connected to a mobile API yet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
