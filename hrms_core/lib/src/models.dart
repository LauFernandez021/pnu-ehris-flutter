import 'format.dart';

class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});
  final int id;
  final String name;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as int,
    name: j['name'] as String,
    email: j['email'] as String,
  );
}

class LoginResult {
  const LoginResult({
    required this.token,
    required this.user,
    required this.roles,
    this.mustChangePassword = false,
  });

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'must_change_password': mustChangePassword,
    },
    'roles': roles,
  };
  final String token;
  final AuthUser user;
  final List<String> roles;
  final bool mustChangePassword;

  LoginResult copyWith({bool? mustChangePassword}) => LoginResult(
    token: token,
    user: user,
    roles: roles,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
  );

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
    token: j['token'] as String,
    user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
    roles: List<String>.from(j['roles'] as List),
    mustChangePassword:
        (j['user'] as Map<String, dynamic>)['must_change_password'] as bool? ??
        false,
  );
}

class Department {
  const Department({required this.id, required this.name});
  final int id;
  final String name;

  factory Department.fromJson(Map<String, dynamic> j) =>
      Department(id: j['id'] as int, name: j['name'] as String);
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.actorName,
    this.actorEmail,
    this.subjectType,
    this.subjectId,
    this.ip,
    this.meta = const {},
  });

  final int id;
  final String action;
  final DateTime createdAt;
  final String? actorName;
  final String? actorEmail;
  final String? subjectType;
  final int? subjectId;
  final String? ip;
  final Map<String, dynamic> meta;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final rawMeta = json['meta'];

    return AuditLogEntry(
      id: json['id'] as int,
      action: json['action'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      actorName: actor?['name'] as String?,
      actorEmail: actor?['email'] as String?,
      subjectType: json['subject_type'] as String?,
      subjectId: json['subject_id'] as int?,
      ip: json['ip'] as String?,
      meta: rawMeta is Map<String, dynamic> ? rawMeta : const {},
    );
  }
}

class LeaveType {
  const LeaveType({
    required this.id,
    required this.name,
    required this.daysPerYear,
    this.attachmentRequiredFromDays,
    this.archivedAt,
  });

  final int id;
  final String name;
  final int daysPerYear;
  final int? attachmentRequiredFromDays;
  final DateTime? archivedAt;

  factory LeaveType.fromJson(Map<String, dynamic> json) => LeaveType(
    id: json['id'] as int,
    name: json['name'] as String,
    daysPerYear: (json['days_per_year'] as num).toInt(),
    attachmentRequiredFromDays: (json['attachment_required_from_days'] as num?)
        ?.toInt(),
    archivedAt: DateTime.tryParse(json['deleted_at'] as String? ?? ''),
  );
}

class Employee {
  const Employee({
    required this.id,
    required this.employeeNo,
    required this.firstName,
    required this.lastName,
    required this.status,
    this.position,
    this.email,
    this.department,
    this.departmentId,
    this.dateHired,
    this.role,
    this.deviceUserId,
    this.badgeNumber,
    this.rfidCardNumber,
    this.hasDocuments = false,
    this.selfRegistered = false,
    this.reviewedAt,
    this.reviewNote,
  });
  final int id;
  final String employeeNo;
  final String firstName;
  final String lastName;
  final String status;
  final String? position;
  final String? email;
  final String? department;
  final int? departmentId;
  final String? dateHired; // yyyy-MM-dd
  final String? role;
  final String? deviceUserId;
  final String? badgeNumber;
  final String? rfidCardNumber;
  final bool hasDocuments;
  final bool selfRegistered;
  final DateTime? reviewedAt;
  final String? reviewNote;

  String get fullName => '$firstName $lastName';

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
    id: j['id'] as int,
    employeeNo: j['employee_no'] as String,
    firstName: j['first_name'] as String,
    lastName: j['last_name'] as String,
    status: j['status'] as String,
    position: j['position'] as String?,
    email: (j['user'] as Map?)?['email'] as String?,
    department: (j['department'] as Map?)?['name'] as String?,
    departmentId: j['department_id'] as int?,
    dateHired: j['date_hired'] as String?,
    role: j['role'] as String?,
    deviceUserId: j['device_user_id'] as String?,
    badgeNumber: j['badge_number'] as String?,
    rfidCardNumber: j['rfid_card_number'] as String?,
    hasDocuments: j['has_documents'] as bool? ?? false,
    selfRegistered: j['self_registered'] as bool? ?? false,
    reviewedAt: DateTime.tryParse(j['reviewed_at'] as String? ?? '')?.toLocal(),
    reviewNote: j['review_note'] as String?,
  );
}

class LeaveBalance {
  const LeaveBalance({
    required this.leaveTypeId,
    required this.leaveType,
    required this.allocated,
    required this.used,
    required this.remaining,
    required this.pending,
    this.attachmentFromDays,
  });
  final int leaveTypeId;
  final String leaveType;
  final double allocated;
  final double used;
  final double remaining;
  final double pending;

  /// null = no attachment for this type. N = proof required from N working days.
  final int? attachmentFromDays;

  /// What can still be requested right now.
  double get available => remaining - pending;

  factory LeaveBalance.fromJson(Map<String, dynamic> j) => LeaveBalance(
    leaveTypeId: j['leave_type_id'] as int,
    leaveType: j['leave_type'] as String,
    allocated: (j['allocated'] as num).toDouble(),
    used: (j['used'] as num).toDouble(),
    remaining: (j['remaining'] as num).toDouble(),
    pending: (j['pending'] as num).toDouble(),
    attachmentFromDays: j['attachment_from_days'] as int?,
  );
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    this.reason,
    this.reviewNote,
    this.employeeName = '',
    this.employeeNo = '',
    this.hasAttachment = false,
    this.attachmentName,
  });
  final int id;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double days;
  final String status;
  final String? reason;
  final String? reviewNote;
  final String employeeName;
  final String employeeNo;
  final bool hasAttachment;
  final String? attachmentName;

  bool get isPending => status == 'pending';

  factory LeaveRequest.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>?;
    return LeaveRequest(
      id: j['id'] as int,
      leaveType: (j['leave_type'] as Map?)?['name'] as String? ?? '',
      startDate: DateTime.parse((j['start_date'] as String).substring(0, 10)),
      endDate: DateTime.parse((j['end_date'] as String).substring(0, 10)),
      days: (j['days'] as num).toDouble(),
      status: j['status'] as String,
      reason: j['reason'] as String?,
      reviewNote: j['review_note'] as String?,
      employeeName: emp == null
          ? ''
          : '${emp['first_name']} ${emp['last_name']}',
      employeeNo: emp == null ? '' : '${emp['employee_no']}',
      hasAttachment: j['has_attachment'] as bool? ?? false,
      attachmentName: j['attachment_name'] as String?,
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.activeEmployees,
    required this.departments,
    required this.pendingLeave,
    required this.onLeaveToday,
    required this.pendingAccounts,
    required this.pendingPassSlips,
    required this.passSlipsToday,
  });
  final int activeEmployees;
  final int departments;
  final int pendingLeave;
  final int onLeaveToday;
  final int pendingAccounts;
  final int pendingPassSlips;
  final int passSlipsToday;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
    activeEmployees: j['active_employees'] as int,
    departments: j['departments'] as int,
    pendingLeave: j['pending_leave'] as int,
    onLeaveToday: j['on_leave_today'] as int,
    pendingAccounts: j['pending_accounts'] as int,
    pendingPassSlips: j['pending_pass_slips'] as int,
    passSlipsToday: j['pass_slips_today'] as int,
  );
}

class PassSlip {
  const PassSlip({
    required this.id,
    required this.slipType,
    required this.slipDate,
    required this.timeOut,
    required this.timeIn,
    required this.destination,
    required this.status,
    this.reason,
    this.reviewNote,
    this.employeeName = '',
    this.employeeNo = '',
  });
  final int id;
  final String slipType; // personal | official
  final DateTime slipDate;
  final String timeOut; // HH:mm
  final String timeIn; // HH:mm
  final String destination;
  final String status;
  final String? reason;
  final String? reviewNote;
  final String employeeName;
  final String employeeNo;

  bool get isPending => status == 'pending';
  String get typeLabel =>
      slipType == 'official' ? 'Official business' : 'Personal';

  factory PassSlip.fromJson(Map<String, dynamic> j) {
    final emp = j['employee'] as Map<String, dynamic>?;
    return PassSlip(
      id: j['id'] as int,
      slipType: j['slip_type'] as String,
      slipDate: DateTime.parse((j['slip_date'] as String).substring(0, 10)),
      timeOut: (j['time_out'] as String).substring(0, 5),
      timeIn: (j['time_in'] as String).substring(0, 5),
      destination: j['destination'] as String,
      status: j['status'] as String,
      reason: j['reason'] as String?,
      reviewNote: j['review_note'] as String?,
      employeeName: emp == null
          ? ''
          : '${emp['first_name']} ${emp['last_name']}',
      employeeNo: emp == null ? '' : '${emp['employee_no']}',
    );
  }
}

class AttendanceSettings {
  const AttendanceSettings({
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
  });

  final String startTime;
  final String endTime;
  final int graceMinutes;

  String get scheduleLabel => '${timeLabel(startTime)} – ${timeLabel(endTime)}';

  factory AttendanceSettings.fromJson(Map<String, dynamic> json) =>
      AttendanceSettings(
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        graceMinutes: json['grace_minutes'] as int,
      );
}

class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.status,
    required this.workedMinutes,
    this.checkInAt,
    this.checkOutAt,
    this.amInAt,
    this.amOutAt,
    this.pmInAt,
    this.pmOutAt,
    this.otInAt,
    this.otOutAt,
    this.employeeId,
    this.employeeNo,
    this.employeeName,
    this.department,
  });

  final DateTime date;
  final String status;
  final int workedMinutes;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? amInAt;
  final DateTime? amOutAt;
  final DateTime? pmInAt;
  final DateTime? pmOutAt;
  final DateTime? otInAt;
  final DateTime? otOutAt;
  final int? employeeId;
  final String? employeeNo;
  final String? employeeName;
  final String? department;

  String get workedTimeLabel {
    final hours = workedMinutes ~/ 60;
    final minutes = workedMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String timeLabelFor(DateTime? time) {
    if (time == null) return '—';
    return timeLabel(hhmm(time.hour, time.minute));
  }

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
    date: DateTime.parse(json['date'] as String),
    status: json['status'] as String,
    workedMinutes: json['worked_minutes'] as int,
    checkInAt: json['check_in_at'] == null
        ? null
        : DateTime.parse(json['check_in_at'] as String).toLocal(),
    checkOutAt: json['check_out_at'] == null
        ? null
        : DateTime.parse(json['check_out_at'] as String).toLocal(),
    amInAt: json['am_in_at'] == null
        ? (json['check_in_at'] == null
              ? null
              : DateTime.parse(json['check_in_at'] as String).toLocal())
        : DateTime.parse(json['am_in_at'] as String).toLocal(),
    amOutAt: json['am_out_at'] == null
        ? null
        : DateTime.parse(json['am_out_at'] as String).toLocal(),
    pmInAt: json['pm_in_at'] == null
        ? null
        : DateTime.parse(json['pm_in_at'] as String).toLocal(),
    pmOutAt: json['pm_out_at'] == null
        ? (json['check_out_at'] == null
              ? null
              : DateTime.parse(json['check_out_at'] as String).toLocal())
        : DateTime.parse(json['pm_out_at'] as String).toLocal(),
    otInAt: json['ot_in_at'] == null
        ? null
        : DateTime.parse(json['ot_in_at'] as String).toLocal(),
    otOutAt: json['ot_out_at'] == null
        ? null
        : DateTime.parse(json['ot_out_at'] as String).toLocal(),
    employeeId: json['employee_id'] as int?,
    employeeNo: json['employee_no'] as String?,
    employeeName: json['employee_name'] as String?,
    department: json['department'] as String?,
  );
}

class AttendanceHistory {
  const AttendanceHistory({required this.settings, required this.days});

  final AttendanceSettings settings;
  final List<AttendanceDay> days;

  factory AttendanceHistory.fromJson(Map<String, dynamic> json) =>
      AttendanceHistory(
        settings: AttendanceSettings.fromJson(
          json['settings'] as Map<String, dynamic>,
        ),
        days: (json['days'] as List)
            .map((day) => AttendanceDay.fromJson(day as Map<String, dynamic>))
            .toList(),
      );
}

class AttendanceReport {
  const AttendanceReport({
    required this.date,
    required this.settings,
    required this.counts,
    required this.days,
  });

  final DateTime date;
  final AttendanceSettings settings;
  final Map<String, int> counts;
  final List<AttendanceDay> days;

  factory AttendanceReport.fromJson(Map<String, dynamic> json) =>
      AttendanceReport(
        date: DateTime.parse(json['date'] as String),
        settings: AttendanceSettings.fromJson(
          json['settings'] as Map<String, dynamic>,
        ),
        counts: (json['counts'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, value as int),
        ),
        days: (json['data'] as List)
            .map((day) => AttendanceDay.fromJson(day as Map<String, dynamic>))
            .toList(),
      );
}

class DtrEmployeeOption {
  const DtrEmployeeOption({
    required this.id,
    required this.employeeNo,
    required this.name,
    this.designation,
    this.department,
  });

  final int id;
  final String employeeNo;
  final String name;
  final String? designation;
  final String? department;

  factory DtrEmployeeOption.fromJson(Map<String, dynamic> json) =>
      DtrEmployeeOption(
        id: json['id'] as int,
        employeeNo: json['employee_no'] as String,
        name: json['employee_name'] as String,
        designation: json['designation'] as String?,
        department: json['department'] as String?,
      );
}

class DtrEntry {
  const DtrEntry({
    required this.date,
    required this.status,
    required this.workedMinutes,
    this.checkInAt,
    this.checkOutAt,
    this.amInAt,
    this.amOutAt,
    this.pmInAt,
    this.pmOutAt,
    this.otInAt,
    this.otOutAt,
  });

  final DateTime date;
  final String status;
  final int workedMinutes;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final DateTime? amInAt;
  final DateTime? amOutAt;
  final DateTime? pmInAt;
  final DateTime? pmOutAt;
  final DateTime? otInAt;
  final DateTime? otOutAt;

  String get workedTimeLabel {
    final hours = workedMinutes ~/ 60;
    final minutes = workedMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String timeLabelFor(DateTime? time) {
    if (time == null) return '—';
    return timeLabel(hhmm(time.hour, time.minute));
  }

  factory DtrEntry.fromJson(Map<String, dynamic> json) => DtrEntry(
    date: DateTime.parse(json['date'] as String),
    status: json['status'] as String,
    workedMinutes: json['worked_minutes'] as int,
    checkInAt: json['check_in_at'] == null
        ? null
        : DateTime.parse(json['check_in_at'] as String).toLocal(),
    checkOutAt: json['check_out_at'] == null
        ? null
        : DateTime.parse(json['check_out_at'] as String).toLocal(),
    amInAt: json['am_in_at'] == null
        ? (json['check_in_at'] == null
              ? null
              : DateTime.parse(json['check_in_at'] as String).toLocal())
        : DateTime.parse(json['am_in_at'] as String).toLocal(),
    amOutAt: json['am_out_at'] == null
        ? null
        : DateTime.parse(json['am_out_at'] as String).toLocal(),
    pmInAt: json['pm_in_at'] == null
        ? null
        : DateTime.parse(json['pm_in_at'] as String).toLocal(),
    pmOutAt: json['pm_out_at'] == null
        ? (json['check_out_at'] == null
              ? null
              : DateTime.parse(json['check_out_at'] as String).toLocal())
        : DateTime.parse(json['pm_out_at'] as String).toLocal(),
    otInAt: json['ot_in_at'] == null
        ? null
        : DateTime.parse(json['ot_in_at'] as String).toLocal(),
    otOutAt: json['ot_out_at'] == null
        ? null
        : DateTime.parse(json['ot_out_at'] as String).toLocal(),
  );
}

class DtrEmployeeRecord {
  const DtrEmployeeRecord({
    required this.id,
    required this.employeeNo,
    required this.name,
    required this.entries,
    this.designation,
  });

  final int id;
  final String employeeNo;
  final String name;
  final String? designation;
  final List<DtrEntry> entries;

  factory DtrEmployeeRecord.fromJson(Map<String, dynamic> json) =>
      DtrEmployeeRecord(
        id: json['id'] as int,
        employeeNo: json['employee_no'] as String,
        name: json['employee_name'] as String,
        designation: json['designation'] as String?,
        entries: (json['entries'] as List)
            .map((entry) => DtrEntry.fromJson(entry as Map<String, dynamic>))
            .toList(),
      );
}

class DtrBatch {
  const DtrBatch({
    required this.id,
    required this.code,
    required this.periodType,
    required this.year,
    required this.month,
    required this.startDate,
    required this.endDate,
    required this.transactionDate,
    required this.employeeCount,
    this.payPeriod,
    this.remarks,
    this.employees = const [],
  });

  final int id;
  final String code;
  final String periodType;
  final String? payPeriod;
  final int year;
  final int month;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime transactionDate;
  final String? remarks;
  final int employeeCount;
  final List<DtrEmployeeRecord> employees;

  String get periodLabel {
    final monthLabel = shortDate(DateTime(year, month, 1)).split(' ').first;
    if (periodType == 'monthly') return '$monthLabel $year · Monthly';
    final cutoff = payPeriod == 'first_cutoff' ? '1st cutoff' : '2nd cutoff';
    return '$monthLabel $year · $cutoff';
  }

  factory DtrBatch.fromJson(Map<String, dynamic> json) => DtrBatch(
    id: json['id'] as int,
    code: json['dtr_code'] as String,
    periodType: json['period_type'] as String,
    payPeriod: json['pay_period'] as String?,
    year: json['year'] as int,
    month: json['month'] as int,
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    transactionDate: DateTime.parse(json['transaction_date'] as String),
    remarks: json['remarks'] as String?,
    employeeCount: json['employee_count'] as int,
    employees: (json['employees'] as List? ?? const [])
        .map(
          (employee) =>
              DtrEmployeeRecord.fromJson(employee as Map<String, dynamic>),
        )
        .toList(),
  );
}
