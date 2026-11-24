import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/pnu_filing_requests_tab.dart';

void main() {
  testWidgets('overtime request times open time pickers', (tester) async {
    await _openRequestType(tester, 'overtime');
    await tester.tap(find.text('Overtime start'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets('shift change schedule times open time pickers', (tester) async {
    await _openRequestType(tester, 'shift_change');
    await tester.tap(find.text('Current schedule (optional)'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}

Future<void> _openRequestType(WidgetTester tester, String requestType) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: PnuFilingRequestPage(requestType: requestType)),
    ),
  );
}
