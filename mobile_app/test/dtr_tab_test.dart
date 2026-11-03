import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:mobile_app/dtr_tab.dart';
import 'package:mobile_app/providers.dart';

void main() {
  testWidgets('shows live attendance punches alongside generated DTRs', (
    tester,
  ) async {
    final checkIn = DateTime(2026, 10, 30, 8);
    final history = AttendanceHistory(
      settings: const AttendanceSettings(
        startTime: '08:00',
        endTime: '17:00',
        graceMinutes: 10,
      ),
      days: [
        AttendanceDay(
          date: DateTime(2026, 10, 30),
          status: 'present',
          workedMinutes: 0,
          checkInAt: checkIn,
          amInAt: checkIn,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceProvider.overrideWith((ref) async => history),
          myDtrBatchesProvider.overrideWith((ref) async => <DtrBatch>[]),
        ],
        child: const MaterialApp(home: Scaffold(body: DtrTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent attendance logs'), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(
      find.text('No official DTR periods are available yet.'),
      findsOneWidget,
    );
  });
}
