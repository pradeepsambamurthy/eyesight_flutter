// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Screens / Shell
import 'screens/app_shell.dart'; // hosts the constant header + tabs (incl. Report tab)
import 'screens/login_gate.dart'; // standalone gate screen (optional, used by '/login')
import 'screens/capture_screen.dart'; // '/start'
import 'screens/acuity_test_screen.dart'; // '/test'

// NOTE: Do NOT import 'report_screen.dart' here — the Report UI is shown inside AppShell’s Report tab
// NOTE: We also don’t need to import login_screen.dart here (it’s used inside AppShell’s overlay)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VisionApp());
}

class VisionApp extends StatelessWidget {
  const VisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E60E6),
        brightness: Brightness.light,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EyeSight',
      theme: theme,

      // Constant header + tabs live in the shell
      home: const AppShell(),

      // Static routes (avoid `const` inside the builders)
      routes: {
        '/start': (_) => const CaptureScreen(),
        '/test': (_) => const AcuityTestScreen(),

        // Keep Login as a simple route if you still use it
        '/login': (_) => LoginGate(),

        // Jump back to the shell
        '/app': (_) => const AppShell(),
      },

      // Optional: allow deep-linking to '/report' to open the Report tab in the shell
      onGenerateRoute: (settings) {
        if (settings.name == '/report') {
          // AppSection is defined in app_shell.dart
          return MaterialPageRoute(
            builder: (_) => const AppShell(initialTab: AppSection.report),
          );
        }
        return null; // fall back to `routes` / unknown route behavior
      },
    );
  }
}
