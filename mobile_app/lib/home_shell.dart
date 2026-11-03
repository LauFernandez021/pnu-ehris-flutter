import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'approvals_tab.dart';
import 'attendance_tab.dart';
import 'dtr_tab.dart';
import 'home_tab.dart';
import 'internet_status_notice.dart';
import 'providers.dart';
import 'new_request_sheet.dart';
import 'requests_tab.dart';
import 'updater.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider)!;
    final isManager = session.roles.contains('manager');
    final approvals = isManager
        ? ref
                  .watch(approvalsProvider)
                  .maybeWhen(data: (l) => l.length, orElse: () => 0) +
              ref
                  .watch(passSlipApprovalsProvider)
                  .maybeWhen(data: (l) => l.length, orElse: () => 0)
        : 0;

    final titles = [
      'Home',
      'Attendance',
      'My DTR',
      'My requests',
      if (isManager) 'Approvals',
    ];
    final pages = <Widget>[
      const HomeTab(),
      const AttendanceTab(),
      const DtrTab(),
      const RequestsTab(),
      if (isManager) const ApprovalsTab(),
    ];
    if (_tab >= pages.length) _tab = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (value) {
              if (value == 'password') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PasswordChangePage(
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
          Expanded(child: pages[_tab]),
        ],
      ),
      floatingActionButton: _tab == 1 || _tab == 2 || (isManager && _tab == 4)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showNewRequestSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('New request'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'Attendance',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'DTR',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Requests',
          ),
          if (isManager)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: approvals > 0,
                label: Text('$approvals'),
                child: const Icon(Icons.fact_check_outlined),
              ),
              selectedIcon: const Icon(Icons.fact_check),
              label: 'Approvals',
            ),
        ],
      ),
    );
  }
}
