import 'api_client.dart';
import 'format.dart';
import 'models.dart';

import 'dart:typed_data';

import 'package:dio/dio.dart';

class AuthService {
  AuthService(this.api);
  final ApiClient api;
  Future<String> register({
    required String employeeNo,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required Uint8List idPhoto,
    required Uint8List selfie,
    String? registrationCode,
  }) async {
    final form = FormData.fromMap({
      'employee_no': employeeNo,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'password_confirmation': password,
      if (registrationCode != null && registrationCode.trim().isNotEmpty)
        'registration_code': registrationCode.trim(),
      'id_photo': MultipartFile.fromBytes(idPhoto, filename: 'id.jpg'),
      'selfie': MultipartFile.fromBytes(selfie, filename: 'selfie.jpg'),
    });
    final data = await api.post('/register', data: form);
    return (data as Map)['message'] as String;
  }

  Future<LoginResult> login(
    String email,
    String password, {
    String deviceName = 'desktop',
  }) async {
    final data = await api.post(
      '/login',
      data: {'email': email, 'password': password, 'device_name': deviceName},
    );
    return LoginResult.fromJson(data as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.post(
      '/me/password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      },
    );
  }

  /// Pass [token] to revoke a token that isn't in the session yet.
  Future<void> logout({String? token}) async {
    await api.post(
      '/logout',
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    );
  }
}

class AuditLogService {
  AuditLogService(this.api);
  final ApiClient api;

  Future<AuditLogPage> list({
    int page = 1,
    String? action,
    String? subjectType,
    String? actorId,
    String? subjectId,
    String? from,
    String? to,
  }) async {
    final data = await api.get(
      '/audit-logs',
      query: {
        'page': page,
        'per_page': 50,
        if (action != null && action.trim().isNotEmpty) 'action': action.trim(),
        if (subjectType != null && subjectType.trim().isNotEmpty)
          'subject_type': subjectType.trim(),
        if (actorId != null && actorId.trim().isNotEmpty)
          'actor_id': actorId.trim(),
        if (subjectId != null && subjectId.trim().isNotEmpty)
          'subject_id': subjectId.trim(),
        if (from != null && from.trim().isNotEmpty) 'from': from.trim(),
        if (to != null && to.trim().isNotEmpty) 'to': to.trim(),
      },
    ) as Map<String, dynamic>;
    final logs = (data['data'] as List)
        .map((item) => AuditLogEntry.fromJson(item as Map<String, dynamic>))
        .toList();

    return AuditLogPage(
      logs: logs,
      currentPage: data['current_page'] as int,
      lastPage: data['last_page'] as int,
    );
  }
}

class AuditLogPage {
  const AuditLogPage({
    required this.logs,
    required this.currentPage,
    required this.lastPage,
  });

  final List<AuditLogEntry> logs;
  final int currentPage;
  final int lastPage;
}

class EmployeeService {
  EmployeeService(this.api);
  final ApiClient api;

  Future<List<Employee>> list({
    int page = 1,
    String? status,
    bool selfRegistered = false,
  }) async {
    final data = await api.get(
      '/employees',
      query: {
        'page': page,
        'per_page': 200,
        if (status != null) 'status': status,
        if (selfRegistered) 'self_registered': 1,
      },
    ) as Map<String, dynamic>;
    return (data['data'] as List)
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approve(
    int id, {
    int? departmentId,
    String? position,
    String? deviceUserId,
  }) {
    String? blankToNull(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    return api.post(
      '/employees/$id/approve',
      data: {
        'department_id': departmentId,
        'position': blankToNull(position),
        'device_user_id': blankToNull(deviceUserId),
      },
    );
  }

  Future<void> reject(int id, String note) =>
      api.post('/employees/$id/reject', data: {'note': note});
  Future<Employee> create({
    required String email,
    required String password,
    required String role,
    required String employeeNo,
    required String firstName,
    required String lastName,
    int? departmentId,
    String? position,
    DateTime? dateHired,
    String? deviceUserId,
    String? rfidCardNumber,
  }) async {
    final data = await api.post(
      '/employees',
      data: {
        'email': email,
        'password': password,
        'role': role,
        'employee_no': employeeNo,
        'first_name': firstName,
        'last_name': lastName,
        if (departmentId != null) 'department_id': departmentId,
        if (position != null && position.isNotEmpty) 'position': position,
        if (deviceUserId != null && deviceUserId.isNotEmpty)
          'device_user_id': deviceUserId,
        if (rfidCardNumber != null && rfidCardNumber.trim().isNotEmpty)
          'rfid_card_number': rfidCardNumber.trim(),
        if (dateHired != null)
          'date_hired': dateHired.toIso8601String().split('T').first,
      },
    );
    return Employee.fromJson(data as Map<String, dynamic>);
  }

  Future<Employee> update(int id, Map<String, dynamic> changes) async {
    final data = await api.put('/employees/$id', data: changes);
    return Employee.fromJson(data as Map<String, dynamic>);
  }

  Future<void> archive(int id) => api.delete('/employees/$id');
}

class DepartmentService {
  DepartmentService(this.api);
  final ApiClient api;

  Future<List<Department>> list() async {
    final data = await api.get('/departments') as List;
    return data
        .map((e) => Department.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Department> create(String name) async => Department.fromJson(
    await api.post('/departments', data: {'name': name})
        as Map<String, dynamic>,
  );

  Future<Department> update(int id, String name) async => Department.fromJson(
    await api.put('/departments/$id', data: {'name': name})
        as Map<String, dynamic>,
  );

  Future<void> archive(int id) => api.delete('/departments/$id');
}

class LeaveService {
  LeaveService(this.api);
  final ApiClient api;

  List<T> _items<T>(dynamic data, T Function(Map<String, dynamic>) parse) {
    final list = data is Map ? data['data'] as List : data as List;
    return list.map((e) => parse(e as Map<String, dynamic>)).toList();
  }

  Future<List<LeaveBalance>> myBalances() async =>
      _items(await api.get('/me/leave-balances'), LeaveBalance.fromJson);

  Future<List<LeaveRequest>> myRequests() async =>
      _items(await api.get('/me/leave-requests'), LeaveRequest.fromJson);

  Future<LeaveRequest> submit({
    required int leaveTypeId,
    required DateTime start,
    required DateTime end,
    String? reason,
    Uint8List? attachment,
    String attachmentName = 'proof.jpg',
  }) async {
    final form = FormData.fromMap({
      'leave_type_id': leaveTypeId,
      'start_date': ymd(start),
      'end_date': ymd(end),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (attachment != null)
        'attachment': MultipartFile.fromBytes(
          attachment,
          filename: attachmentName,
        ),
    });
    final data = await api.post('/leave-requests', data: form);
    return LeaveRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cancel(int id) => api.post('/leave-requests/$id/cancel');

  /// Requests the signed-in approver is allowed to review.
  Future<List<LeaveRequest>> review({String? status}) async => _items(
    await api.get(
      '/leave-requests',
      query: {if (status != null) 'status': status},
    ),
    LeaveRequest.fromJson,
  );

  Future<void> approve(int id, {String? note}) => api.post(
    '/leave-requests/$id/approve',
    data: {if (note != null && note.isNotEmpty) 'note': note},
  );

  Future<void> reject(int id, String note) =>
      api.post('/leave-requests/$id/reject', data: {'note': note});

  Future<void> archive(int id) => api.delete('/leave-requests/$id');
}

class LeaveTypeService {
  LeaveTypeService(this.api);
  final ApiClient api;

  Future<List<LeaveType>> list({bool archived = false}) async {
    final data = await api.get(
      '/settings/leave-types',
      query: {if (archived) 'trashed': 'only'},
    ) as List;
    return data
        .map((item) => LeaveType.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LeaveType> create({
    required String name,
    required int daysPerYear,
    int? attachmentRequiredFromDays,
  }) async {
    final data = await api.post(
      '/settings/leave-types',
      data: {
        'name': name,
        'days_per_year': daysPerYear,
        'attachment_required_from_days': attachmentRequiredFromDays,
      },
    );
    return LeaveType.fromJson(data as Map<String, dynamic>);
  }

  Future<LeaveType> updateType({
    required int id,
    required String name,
    required int daysPerYear,
    int? attachmentRequiredFromDays,
  }) async {
    final data = await api.put(
      '/settings/leave-types/$id',
      data: {
        'name': name,
        'days_per_year': daysPerYear,
        'attachment_required_from_days': attachmentRequiredFromDays,
      },
    );
    return LeaveType.fromJson(data as Map<String, dynamic>);
  }

  Future<void> archive(int id) => api.delete('/settings/leave-types/$id');

  Future<void> restore(int id) => api.post('/settings/leave-types/$id/restore');
}

class DashboardService {
  DashboardService(this.api);
  final ApiClient api;

  Future<DashboardSummary> summary() async => DashboardSummary.fromJson(
    await api.get('/dashboard/summary') as Map<String, dynamic>,
  );
}

class PassSlipService {
  PassSlipService(this.api);
  final ApiClient api;

  List<PassSlip> _parse(dynamic data) {
    final list = data is Map ? data['data'] as List : data as List;
    return list
        .map((e) => PassSlip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PassSlip>> mine() async =>
      _parse(await api.get('/me/pass-slips'));

  Future<PassSlip> submit({
    required String slipType,
    required DateTime date,
    required String timeOut,
    required String timeIn,
    required String destination,
    String? reason,
  }) async {
    final data = await api.post(
      '/pass-slips',
      data: {
        'slip_type': slipType,
        'slip_date': ymd(date),
        'time_out': timeOut,
        'time_in': timeIn,
        'destination': destination.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return PassSlip.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cancel(int id) => api.post('/pass-slips/$id/cancel');

  Future<List<PassSlip>> review({String? status}) async => _parse(
    await api.get('/pass-slips', query: {if (status != null) 'status': status}),
  );

  Future<void> approve(int id, {String? note}) => api.post(
    '/pass-slips/$id/approve',
    data: {if (note != null && note.isNotEmpty) 'note': note},
  );

  Future<void> reject(int id, String note) =>
      api.post('/pass-slips/$id/reject', data: {'note': note});

  Future<void> archive(int id) => api.delete('/pass-slips/$id');
}

class AttendanceService {
  AttendanceService(this.api);
  final ApiClient api;

  Future<AttendanceHistory> mine() async => AttendanceHistory.fromJson(
    await api.get('/me/attendance') as Map<String, dynamic>,
  );

  Future<void> checkIn() async {
    await api.post('/me/attendance/check-in');
  }

  Future<void> checkOut() async {
    await api.post('/me/attendance/check-out');
  }

  Future<void> punch(String slot) async {
    await api.post('/me/attendance/punch', data: {'punch': slot});
  }

  Future<AttendanceReport> report(String date) async =>
      AttendanceReport.fromJson(
        await api.get('/attendance', query: {'date': date})
            as Map<String, dynamic>,
      );
}

class DtrService {
  DtrService(this.api);
  final ApiClient api;

  Future<List<DtrEmployeeOption>> employees() async {
    final data = await api.get('/dtr-employees') as List;
    return data
        .map(
          (employee) =>
              DtrEmployeeOption.fromJson(employee as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<DtrBatch>> list() async {
    final response = await api.get('/dtr-batches') as Map<String, dynamic>;
    return (response['data'] as List)
        .map((batch) => DtrBatch.fromJson(batch as Map<String, dynamic>))
        .toList();
  }

  Future<List<DtrBatch>> mine() async {
    final response = await api.get('/me/dtr-batches') as List;
    return response
        .map((batch) => DtrBatch.fromJson(batch as Map<String, dynamic>))
        .toList();
  }

  Future<DtrBatch> showMine(int id) async => DtrBatch.fromJson(
    await api.get('/me/dtr-batches/$id') as Map<String, dynamic>,
  );

  Future<DtrBatch> show(int id) async => DtrBatch.fromJson(
    await api.get('/dtr-batches/$id') as Map<String, dynamic>,
  );

  Future<void> archive(int id) => api.delete('/dtr-batches/$id');

  Future<DtrBatch> create({
    required String periodType,
    required int year,
    required int month,
    required String transactionDate,
    required bool allEmployees,
    String? payPeriod,
    String? remarks,
    List<int> employeeIds = const [],
  }) async {
    final data = await api.post(
      '/dtr-batches',
      data: {
        'period_type': periodType,
        if (payPeriod != null) 'pay_period': payPeriod,
        'year': year,
        'month': month,
        'transaction_date': transactionDate,
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
        'employee_selection': allEmployees ? 'all' : 'selected',
        if (!allEmployees) 'employee_ids': employeeIds,
      },
    );
    return DtrBatch.fromJson(data as Map<String, dynamic>);
  }
}
