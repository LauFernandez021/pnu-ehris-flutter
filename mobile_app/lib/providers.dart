import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'session_store.dart';

/// Android emulator reaches your PC at 10.0.2.2. For a real phone use:
/// flutter run --dart-define=API_URL=http://YOUR-PC-IP:8000/api
String get apiBaseUrl {
  const override = String.fromEnvironment('API_URL');
  if (override.isNotEmpty) return override;
  if (kReleaseMode) return 'https://kenneth.mycreativepanda.com/hrms-api/api';
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api';
  }
  return 'http://127.0.0.1:8000/api';
}

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

final internetStatusProvider = StreamProvider<InternetStatus>(
  (ref) => InternetConnection().onStatusChange,
);

final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

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

final balancesProvider = FutureProvider.autoDispose<List<LeaveBalance>>(
  (ref) => guarded(
    ref,
    () => LeaveService(ref.read(apiClientProvider)).myBalances(),
  ),
);

final attendanceProvider = FutureProvider.autoDispose<AttendanceHistory>(
  (ref) =>
      guarded(ref, () => AttendanceService(ref.read(apiClientProvider)).mine()),
);

final myDtrBatchesProvider = FutureProvider.autoDispose<List<DtrBatch>>(
  (ref) => guarded(ref, () => DtrService(ref.read(apiClientProvider)).mine()),
);

final myDtrDetailProvider = FutureProvider.autoDispose.family<DtrBatch, int>(
  (ref, id) =>
      guarded(ref, () => DtrService(ref.read(apiClientProvider)).showMine(id)),
);

final myRequestsProvider = FutureProvider.autoDispose<List<LeaveRequest>>(
  (ref) => guarded(
    ref,
    () => LeaveService(ref.read(apiClientProvider)).myRequests(),
  ),
);

/// Pending requests this person can approve (managers).
final approvalsProvider = FutureProvider.autoDispose<List<LeaveRequest>>(
  (ref) => guarded(
    ref,
    () => LeaveService(ref.read(apiClientProvider)).review(status: 'pending'),
  ),
);
final myPassSlipsProvider = FutureProvider.autoDispose<List<PassSlip>>(
  (ref) =>
      guarded(ref, () => PassSlipService(ref.read(apiClientProvider)).mine()),
);

final passSlipApprovalsProvider = FutureProvider.autoDispose<List<PassSlip>>(
  (ref) => guarded(
    ref,
    () =>
        PassSlipService(ref.read(apiClientProvider)).review(status: 'pending'),
  ),
);
