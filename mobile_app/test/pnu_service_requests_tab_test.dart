import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/pnu_service_requests_tab.dart';

void main() {
  testWidgets('service request time uses the native time picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PnuServiceRequestPage(requestType: 'vehicle'),
        ),
      ),
    );
    await tester.tap(find.text('Choose time needed'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
