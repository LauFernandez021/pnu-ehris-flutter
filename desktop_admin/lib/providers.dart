import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'session_store.dart';

// Change this when the API moves to a real server.
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:8000/api',
);

final initialSessionProvider = Provider<LoginResult?>((ref) => null);

class SessionNotifier extends Notifier<LoginResult?> {
  final _store = SessionStore();

  @override
  LoginResult? build() => ref.read(initialSessionProvider);

  Future<void> signIn(LoginResult result) async {
    await _store.save(result);
    state = result;
  }

  Future<void> signOut() async {
    await _store.clear();
    state = null;
  }

  Future<void> markPasswordChanged() async {
    final current = state;
    if (current == null || !current.mustChangePassword) return;
    final updated = current.copyWith(mustChangePassword: false);
    await _store.save(updated);
    state = updated;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, LoginResult?>(
  SessionNotifier.new,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: apiBaseUrl,
    tokenProvider: () async => ref.read(sessionProvider)?.token,
  );
});

/// Runs an API call. A 401 means the saved token is no longer valid,
/// so we go back to the login screen.
Future<T> guarded<T>(Ref ref, Future<T> Function() call) async {
  try {
    return await call();
  } on ApiException catch (e) {
    if (e.statusCode == 401) {
      await ref.read(sessionProvider.notifier).signOut();
    }
    rethrow;
  }
}

/// Keeps a result for [seconds] so switching pages doesn't hit the server
/// again every time. The refresh buttons and every save still reload it.
void cacheFor(Ref ref, {int seconds = 30}) {
  final link = ref.keepAlive();
  final timer = Timer(Duration(seconds: seconds), link.close);
  ref.onDispose(timer.cancel);
}

final employeesProvider = FutureProvider.autoDispose<List<Employee>>((ref) {
  cacheFor(ref);
  return guarded(
    ref,
    () => EmployeeService(ref.read(apiClientProvider)).list(),
  );
});

final departmentsProvider = FutureProvider.autoDispose<List<Department>>((ref) {
  cacheFor(ref, seconds: 300);
  return guarded(
    ref,
    () => DepartmentService(ref.read(apiClientProvider)).list(),
  );
});

final summaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) {
  cacheFor(ref);
  return guarded(
    ref,
    () => DashboardService(ref.read(apiClientProvider)).summary(),
  );
});

final attendanceReportProvider = FutureProvider.autoDispose
    .family<AttendanceReport, String>((ref, date) {
      cacheFor(ref);
      return guarded(
        ref,
        () => AttendanceService(ref.read(apiClientProvider)).report(date),
      );
    });

final dtrBatchesProvider = FutureProvider.autoDispose<List<DtrBatch>>((ref) {
  cacheFor(ref);
  return guarded(ref, () => DtrService(ref.read(apiClientProvider)).list());
});

final dtrEmployeesProvider =
    FutureProvider.autoDispose<List<DtrEmployeeOption>>((ref) {
      cacheFor(ref, seconds: 300);
      return guarded(
        ref,
        () => DtrService(ref.read(apiClientProvider)).employees(),
      );
    });

final dtrDetailsProvider = FutureProvider.autoDispose.family<DtrBatch, int>((
  ref,
  id,
) {
  return guarded(ref, () => DtrService(ref.read(apiClientProvider)).show(id));
});

final leaveTypesProvider = FutureProvider.autoDispose
    .family<List<LeaveType>, bool>((ref, archived) {
      cacheFor(ref);
      return guarded(
        ref,
        () =>
            LeaveTypeService(ref.read(apiClientProvider))
                .list(archived: archived),
      );
    });

/// Key is a status ('pending', 'approved', 'rejected') or '' for all.
final leaveRequestsProvider = FutureProvider.autoDispose
    .family<List<LeaveRequest>, String>((ref, status) {
      cacheFor(ref);
      return guarded(
        ref,
        () =>
            LeaveService(ref.read(apiClientProvider))
                .review(status: status.isEmpty ? null : status),
      );
    });

final pendingAccountsProvider = FutureProvider.autoDispose<List<Employee>>((
  ref,
) {
  cacheFor(ref);
  return guarded(
    ref,
    () => EmployeeService(ref.read(apiClientProvider)).list(status: 'pending'),
  );
});

final passSlipsProvider = FutureProvider.autoDispose
    .family<List<PassSlip>, String>((ref, status) {
      cacheFor(ref);
      return guarded(
        ref,
        () =>
            PassSlipService(ref.read(apiClientProvider))
                .review(status: status.isEmpty ? null : status),
      );
    });

/// Key: 'pending' | 'approved' | 'rejected'
final accountsProvider = FutureProvider.autoDispose
    .family<List<Employee>, String>((ref, tab) {
      cacheFor(ref);
      final service = EmployeeService(ref.read(apiClientProvider));
      return guarded(ref, () {
        switch (tab) {
          case 'approved':
            return service.list(status: 'active', selfRegistered: true);
          case 'rejected':
            return service.list(status: 'rejected');
          default:
            return service.list(status: 'pending');
        }
      });
    });
