import 'package:flutter_test/flutter_test.dart';
import 'package:hrms_core/hrms_core.dart';

void main() {
  test('login result keeps the forced password change flag in storage', () {
    final result = LoginResult.fromJson({
      'token': 'session-token',
      'user': {
        'id': 12,
        'name': 'Test Admin',
        'email': 'admin@example.test',
        'must_change_password': true,
      },
      'roles': ['admin'],
    });

    expect(result.mustChangePassword, isTrue);
    expect(
      LoginResult.fromJson(result.copyWith(mustChangePassword: false).toJson())
          .mustChangePassword,
      isFalse,
    );
  });

  test('audit log entry parses actor, subject, and metadata', () {
    final entry = AuditLogEntry.fromJson({
      'id': 7,
      'actor': {'id': 12, 'name': 'Test Admin', 'email': 'admin@example.test'},
      'action': 'employee.updated',
      'subject_type': 'App\\Models\\Employee',
      'subject_id': 42,
      'meta': {
        'changed_fields': ['position'],
      },
      'ip': '127.0.0.1',
      'created_at': '2026-11-03T10:20:30.000000Z',
    });

    expect(entry.actorName, 'Test Admin');
    expect(entry.subjectId, 42);
    expect(entry.meta['changed_fields'], ['position']);
  });
}
