import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/pnu_api.dart';
import 'package:mobile_app/pnu_compensatory_time_off_tab.dart';
import 'package:mobile_app/providers.dart';

void main() {
  testWidgets('compensatory time-off periods use date pickers', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pnuCompensatoryTimeOffProvider.overrideWith(
            (ref) async => const PnuCompensatoryTimeOffSummary(
              requests: [],
              availableBalance: 12,
            ),
          ),
        ],
        child: const MaterialApp(home: PnuCompensatoryTimeOffPage()),
      ),
    );
    await tester.tap(find.textContaining('Period from:'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
