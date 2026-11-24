import 'package:hrms_core/hrms_core.dart';

class PnuFilingRequest {
  const PnuFilingRequest({
    required this.id,
    required this.type,
    required this.workDate,
    required this.reason,
    required this.status,
    this.hours,
    this.reviewNote,
  });

  final int id;
  final String type;
  final DateTime workDate;
  final String reason;
  final String status;
  final double? hours;
  final String? reviewNote;

  String get typeLabel => switch (type) {
    'overtime' => 'Overtime',
    'shift_change' => 'Shift change',
    'dtr_correction' => 'DTR correction',
    'manual_dtr' => 'Manual DTR',
    _ => type,
  };
}

class PnuNotification {
  const PnuNotification({
    required this.id,
    required this.title,
    required this.details,
    required this.category,
    required this.postingDate,
  });

  final int id;
  final String title;
  final String details;
  final String category;
  final String postingDate;
}

class PnuServiceRequest {
  const PnuServiceRequest({
    required this.id,
    required this.type,
    required this.controlNumber,
    required this.purpose,
    required this.destination,
    required this.dateNeeded,
    required this.timeNeeded,
    required this.status,
  });

  final int id;
  final String type;
  final String controlNumber;
  final String purpose;
  final String destination;
  final DateTime dateNeeded;
  final String timeNeeded;
  final String status;

  String get typeLabel => type == 'vehicle' ? 'Vehicle request' : 'Locator slip';
}

class PnuCompensatoryTimeOff {
  const PnuCompensatoryTimeOff({
    required this.id,
    required this.controlNumber,
    required this.periodFrom,
    required this.periodTo,
    required this.hours,
    required this.balance,
    required this.balanceAfter,
    required this.status,
  });

  final int id;
  final String controlNumber;
  final DateTime periodFrom;
  final DateTime periodTo;
  final int hours;
  final double balance;
  final double balanceAfter;
  final String status;
}

class PnuCompensatoryTimeOffSummary {
  const PnuCompensatoryTimeOffSummary({
    required this.requests,
    required this.availableBalance,
  });

  final List<PnuCompensatoryTimeOff> requests;
  final double availableBalance;
}

class PnuAuthService {
  PnuAuthService(this._api);

  final ApiClient _api;

  Future<LoginResult> login(
    String username,
    String password, {
    required String deviceName,
  }) async {
    final response = _asMap(
      await _api.post(
        '/mobile_auth/login',
        data: {
          'username': username,
          'password': password,
          'device_name': deviceName,
        },
      ),
    );
    final data = _asMap(response['data'] ?? response);
    return LoginResult.fromJson(data);
  }

  Future<Map<String, dynamic>> me() async {
    final response = _asMap(await _api.get('/mobile_auth/me'));
    return _asMap(response['data'] ?? response);
  }

  Future<List<DtrBatch>> dtr() async {
    final response = _asMap(await _api.get('/mobile_auth/dtr'));
    final records = response['data'];
    if (records is! List) {
      throw ApiException('The PNU EHRIS server returned invalid DTR data.');
    }
    return records
        .map((record) => _dtrBatch(_asMap(record)))
        .toList(growable: false);
  }

  Future<List<PnuFilingRequest>> filingRequests() async {
    final response = _asMap(
      await _api.get('/employee_filing_requests', query: {'mode': 'mine'}),
    );
    final records = response['data'];
    if (records is! List) {
      throw ApiException('The PNU EHRIS server returned invalid request data.');
    }
    return records
        .map((value) => _filingRequest(_asMap(value)))
        .toList(growable: false);
  }

  Future<List<PnuNotification>> notifications() async {
    final response = _asMap(await _api.get('/mobile_auth/notifications'));
    final records = response['data'];
    if (records is! List) {
      throw ApiException('The PNU EHRIS server returned invalid memo data.');
    }
    return records
        .map((value) => _notification(_asMap(value)))
        .toList(growable: false);
  }

  Future<PnuNotification> notification(int id) async {
    final response = _asMap(
      await _api.get('/mobile_auth/notifications/$id'),
    );
    return _notification(_asMap(response['data']));
  }

  Future<void> submitFilingRequest(Map<String, dynamic> data) async {
    final response = _asMap(
      await _api.post('/employee_filing_requests', data: data),
    );
    if (response['ok'] != true) {
      throw ApiException(
        response['msg']?.toString() ?? 'The request could not be submitted.',
      );
    }
  }

  Future<List<PnuServiceRequest>> serviceRequests() async {
    final response = _asMap(await _api.get('/mobile_service_requests'));
    final records = response['data'];
    if (records is! List) {
      throw ApiException('The PNU EHRIS server returned invalid service request data.');
    }
    return records
        .map((value) => _serviceRequest(_asMap(value)))
        .toList(growable: false);
  }

  Future<void> submitServiceRequest(Map<String, dynamic> data) async {
    final response = _asMap(
      await _api.post('/mobile_service_requests', data: data),
    );
    if (response['ok'] != true) {
      throw ApiException(
        response['msg']?.toString() ?? 'The request could not be submitted.',
      );
    }
  }

  Future<PnuCompensatoryTimeOffSummary> compensatoryTimeOffs() async {
    final response = _asMap(
      await _api.get('/mobile_compensatory_time_offs'),
    );
    final records = response['data'];
    if (records is! List) {
      throw ApiException('The PNU EHRIS server returned invalid COC request data.');
    }
    return PnuCompensatoryTimeOffSummary(
      requests: records
          .map((value) => _compensatoryTimeOff(_asMap(value)))
          .toList(growable: false),
      availableBalance: _number(response['coc_balance']),
    );
  }

  Future<void> submitCompensatoryTimeOff(Map<String, dynamic> data) async {
    final response = _asMap(
      await _api.post('/mobile_compensatory_time_offs', data: data),
    );
    if (response['ok'] != true) {
      throw ApiException(
        response['msg']?.toString() ??
            'The compensatory time-off request could not be submitted.',
      );
    }
  }

  Future<void> logout() async {
    await _api.post('/mobile_auth/logout');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _api.post(
      '/mobile_auth/changePassword',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) {
      throw ApiException('The PNU EHRIS server returned an invalid response.');
    }
    final response = value['response'];
    if (response is Map) return Map<String, dynamic>.from(response);
    return Map<String, dynamic>.from(value);
  }

  DtrBatch _dtrBatch(Map<String, dynamic> json) {
    final startDate = _date(json['start_date']);
    final endDate = _date(json['end_date']);
    final rawEmployee = _asMap(json['employee']);
    final rawEntries = json['entries'];
    if (rawEntries is! List) {
      throw ApiException('The PNU EHRIS server returned invalid DTR entries.');
    }
    final entries = rawEntries.map((value) {
      final entry = _asMap(value);
      final date = _date(entry['date']);
      final hours = entry['hours_worked'];
      return DtrEntry(
        date: date,
        status: entry['attendanceRecord']?.toString() ?? 'recorded',
        workedMinutes: _workedMinutes(hours),
        amInAt: _time(date, entry['am_in']),
        amOutAt: _time(date, entry['am_out']),
        pmInAt: _time(date, entry['pm_in']),
        pmOutAt: _time(date, entry['pm_out']),
        otInAt: _time(date, entry['ot_in']),
        otOutAt: _time(date, entry['ot_out']),
      );
    }).toList(growable: false);
    final period = (json['period'] as String? ?? '').toLowerCase();
    final firstCutoff = period.contains('first');
    final isCutoff = firstCutoff || period.contains('second');
    final transactionDate = _date(json['transaction_date'] ?? json['start_date']);

    return DtrBatch(
      id: _int(json['id']),
      code: json['code'] as String? ?? '',
      periodType: isCutoff ? 'biweekly' : 'monthly',
      payPeriod: isCutoff
          ? (firstCutoff ? 'first_cutoff' : 'second_cutoff')
          : null,
      year: startDate.year,
      month: startDate.month,
      startDate: startDate,
      endDate: endDate,
      transactionDate: transactionDate,
      employeeCount: 1,
      employees: [
        DtrEmployeeRecord(
          id: _int(rawEmployee['id']),
          employeeNo: rawEmployee['employee_number'] as String? ?? '',
          name: rawEmployee['name'] as String? ?? '',
          entries: entries,
        ),
      ],
    );
  }

  PnuFilingRequest _filingRequest(Map<String, dynamic> json) {
    final workDate = json['work_date'];
    if (workDate is! String || workDate.length < 10) {
      throw ApiException('The PNU EHRIS server returned an invalid request date.');
    }
    final hours = json['hours'];
    return PnuFilingRequest(
      id: _int(json['id']),
      type: json['request_type'] as String? ?? '',
      workDate: DateTime.parse(workDate.substring(0, 10)),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? '',
      hours: hours is num ? hours.toDouble() : double.tryParse('$hours'),
      reviewNote: json['review_note'] as String?,
    );
  }

  PnuNotification _notification(Map<String, dynamic> json) => PnuNotification(
    id: _int(json['id']),
    title: json['title'] as String? ?? '',
    details: json['details'] as String? ?? '',
    category: json['category'] as String? ?? '',
    postingDate: json['posting_date'] as String? ?? '',
  );

  PnuServiceRequest _serviceRequest(Map<String, dynamic> json) {
    final type = json['request_type'];
    if (type != 'vehicle' && type != 'locator') {
      throw ApiException(
        'The PNU EHRIS server returned an invalid service request type.',
      );
    }
    final dateNeeded = _date(json['date_needed']);
    return PnuServiceRequest(
      id: _int(json['id']),
      type: type,
      controlNumber: json['control_no'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      dateNeeded: dateNeeded,
      timeNeeded: json['time_needed'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }

  PnuCompensatoryTimeOff _compensatoryTimeOff(Map<String, dynamic> json) =>
      PnuCompensatoryTimeOff(
        id: _int(json['id']),
        controlNumber: json['control_no'] as String? ?? '',
        periodFrom: _date(json['period_from']),
        periodTo: _date(json['period_to']),
        hours: _int(json['no_of_hours']),
        balance: _number(json['coc_balance']),
        balanceAfter: _number(json['balance_after']),
        status: json['status'] as String? ?? 'pending',
      );

  DateTime _date(dynamic value) {
    if (value is! String || value.length < 10) {
      throw ApiException('The PNU EHRIS server returned an invalid DTR date.');
    }
    return DateTime.parse(value.substring(0, 10));
  }

  int _int(dynamic value) => value is num ? value.toInt() : int.parse('$value');

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw ApiException('The PNU EHRIS server returned an invalid COC balance.');
  }

  int _workedMinutes(dynamic value) {
    if (value == null || value == '') return 0;
    if (value is num) return (value * 60).round();
    if (value is! String) {
      throw ApiException('The PNU EHRIS server returned invalid DTR hours.');
    }
    final hours = double.tryParse(value);
    if (hours != null) return (hours * 60).round();
    final duration = RegExp(
      r'^(\d{1,3}):([0-5]\d)(?::[0-5]\d)?$',
    ).firstMatch(value.trim());
    if (duration == null) {
      throw ApiException('The PNU EHRIS server returned invalid DTR hours.');
    }
    return int.parse(duration[1]!) * 60 + int.parse(duration[2]!);
  }

  DateTime? _time(DateTime date, dynamic value) {
    if (value == null || value == '') return null;
    if (value is! String) {
      throw ApiException('The PNU EHRIS server returned an invalid DTR time.');
    }
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) {
      throw ApiException('The PNU EHRIS server returned an invalid DTR time.');
    }
    var hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final meridiem = match[3]?.toUpperCase();
    if (meridiem == 'PM' && hour < 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) {
      throw ApiException('The PNU EHRIS server returned an invalid DTR time.');
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
