import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:mobile_app/internet_status_notice.dart';
import 'package:mobile_app/providers.dart';

void main() {
  testWidgets('shows an offline notice when there is no internet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          internetStatusProvider.overrideWith(
            (ref) => Stream.value(InternetStatus.disconnected),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InternetStatusNotice())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No internet connection — connect before recording attendance.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides the notice when internet is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          internetStatusProvider.overrideWith(
            (ref) => Stream.value(InternetStatus.connected),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InternetStatusNotice())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No internet connection — connect before recording attendance.',
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.wifi_off), findsNothing);
  });
}
