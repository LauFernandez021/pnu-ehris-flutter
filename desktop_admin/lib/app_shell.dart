import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'account_approvals_page.dart';
import 'audit_logs_page.dart';
import 'attendance_page.dart';
import 'biometric_events_page.dart';
import 'archived_records_page.dart';
import 'dashboard_page.dart';
import 'dtr_page.dart';
import 'departments_page.dart';
import 'employees_page.dart';
import 'requests_page.dart';
import 'settings_page.dart';
import 'providers.dart';
import 'updater.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdate(context, ref);
    });
  }

  Future<void> _logout() async {
    try {
      await AuthService(ref.read(apiClientProvider)).logout();
    } on ApiException {
      // Sign out locally even if the server can't be reached.
    }
    await ref.read(sessionProvider.notifier).signOut();
  }

  Widget _badged(int count, IconData icon) => Badge(
    isLabelVisible: count > 0,
    label: Text('$count'),
    child: Icon(icon),
  );

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width > 1000;
    final summary = ref
        .watch(summaryProvider)
        .maybeWhen(data: (s) => s, orElse: () => null);
    final pendingRequests =
        (summary?.pendingLeave ?? 0) + (summary?.pendingPassSlips ?? 0);
    final pendingAccounts = summary?.pendingAccounts ?? 0;
    final canManageSettings = session.roles.any(
      (role) => role == 'admin' || role == 'hr',
    );
    final isAdmin = session.roles.contains('admin');

    final pages = <Widget>[
      DashboardPage(),
      EmployeesPage(),
      AttendancePage(),
      DtrPage(),
      AccountApprovalsPage(),
      RequestsPage(),
      if (isAdmin) AuditLogsPage(),
      if (canManageSettings) DepartmentsPage(),
      if (canManageSettings) SettingsPage(),
      if (canManageSettings) ArchivedRecordsPage(),
      if (canManageSettings) BiometricEventsPage(),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: wide,
            labelType: wide
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_2, color: scheme.primary, size: 32),
                  if (wide) ...[
                    const SizedBox(width: 10),
                    Text(
                      'HRMS',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Employees'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.access_time_outlined),
                selectedIcon: Icon(Icons.access_time_filled),
                label: Text('Attendance'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: Text('DTR'),
              ),
              NavigationRailDestination(
                icon: _badged(pendingAccounts, Icons.how_to_reg_outlined),
                selectedIcon: _badged(pendingAccounts, Icons.how_to_reg),
                label: const Text('Account approvals'),
              ),
              NavigationRailDestination(
                icon: _badged(pendingRequests, Icons.event_note_outlined),
                selectedIcon: _badged(pendingRequests, Icons.event_note),
                label: const Text('Requests'),
              ),
              if (isAdmin)
                const NavigationRailDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: Text('Audit logs'),
                ),
              if (canManageSettings)
                const NavigationRailDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment),
                  label: Text('Departments'),
                ),
              if (canManageSettings)
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              if (canManageSettings)
                const NavigationRailDestination(
                  icon: Icon(Icons.archive_outlined),
                  selectedIcon: Icon(Icons.archive),
                  label: Text('Archived'),
                ),
              if (canManageSettings)
                const NavigationRailDestination(
                  icon: Icon(Icons.fingerprint_outlined),
                  selectedIcon: Icon(Icons.fingerprint),
                  label: Text('Device logs'),
                ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InitialsAvatar(session.user.name, radius: 20),
                      if (wide) ...[
                        const SizedBox(height: 8),
                        Text(session.user.name),
                      ],
                      IconButton(
                        tooltip: 'Sign out',
                        icon: const Icon(Icons.logout),
                        onPressed: _logout,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
