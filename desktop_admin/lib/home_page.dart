import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'session_store.dart';

// Change this when the API moves to a real server.
const apiBaseUrl = 'http://127.0.0.1:8000/api';

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
}

final sessionProvider =
    NotifierProvider<SessionNotifier, LoginResult?>(SessionNotifier.new);

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

final employeesProvider = FutureProvider.autoDispose<List<Employee>>((ref) =>
    guarded(ref, () => EmployeeService(ref.read(apiClientProvider)).list()));

final departmentsProvider = FutureProvider.autoDispose<List<Department>>((ref) =>
    guarded(ref, () => DepartmentService(ref.read(apiClientProvider)).list()));

final summaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) =>
    guarded(ref, () => DashboardService(ref.read(apiClientProvider)).summary()));

/// Key is a status ('pending', 'approved', 'rejected') or '' for all.
final leaveRequestsProvider = FutureProvider.autoDispose
    .family<List<LeaveRequest>, String>((ref, status) => guarded(
        ref,
        () => LeaveService(ref.read(apiClientProvider))
            .review(status: status.isEmpty ? null : status)));