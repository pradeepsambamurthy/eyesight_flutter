import 'package:flutter/material.dart';
import 'screens/capture_screen.dart';
import 'screens/acuity_test_screen.dart';
import 'screens/report_screen.dart';

void main() => runApp(const EyesightApp());

class EyesightApp extends StatelessWidget {
  const EyesightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eyesight Checker',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      routes: {
        '/': (_) => const CaptureScreen(),
        '/test': (_) => const AcuityTestScreen(),
        '/report': (_) => const ReportScreen(),
      },
      builder: (context, child) => Banner(
        message: 'Not medical advice',
        location: BannerLocation.topEnd,
        color: Colors.orange.withOpacity(.8),
        child: child!,
      ),
    );
  }
}
