import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/app_version_badge.dart';
import 'package:mobile_app/providers.dart';

void main() {
  testWidgets('shows the installed app version', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWith((ref) async => '1.0.3')],
        child: const MaterialApp(
          home: Scaffold(
            body: ColoredBox(color: Colors.indigo, child: AppVersionBadge()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.3'), findsOneWidget);
  });
}
