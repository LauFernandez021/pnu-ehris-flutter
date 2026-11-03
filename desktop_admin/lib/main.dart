import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'app_shell.dart';
import 'login_page.dart';
import 'providers.dart';
import 'session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final saved = await SessionStore().read();
  runApp(
    ProviderScope(
      overrides: [initialSessionProvider.overrideWithValue(saved)],
      child: const HrmsApp(),
    ),
  );
}

class HrmsApp extends ConsumerWidget {
  const HrmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5));

    return MaterialApp(
      title: 'HRMS Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: scheme.surfaceContainerLowest,
        cardTheme: CardThemeData(
          elevation: 0,
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primaryContainer,
        ),
      ),
      home: session == null
          ? const LoginPage()
          : session.mustChangePassword
          ? PasswordChangePage(
              api: ref.read(apiClientProvider),
              mandatory: true,
              onComplete: () =>
                  ref.read(sessionProvider.notifier).markPasswordChanged(),
            )
          : const AppShell(),
    );
  }
}
