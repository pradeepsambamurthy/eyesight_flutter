// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import '../services/report_service.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = ReportService.normalize(ReportService.instance.current);

    String ageText() {
      final typed = r.age;
      final fromFace = r.face?.age;
      final value = typed ?? fromFace;
      return value == null ? '—' : value.toString();
    }

    String genderText() {
      final typed = r.gender;
      final fromFace = r.face?.gender;
      return (typed ?? fromFace) ?? '—';
    }

    String glassesText() {
      final g = r.face?.wearingGlasses;
      if (g == null) return 'No/Unknown';
      return g ? 'Yes' : 'No';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile
          const Text(
            'Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Name: ${r.name ?? '—'}'),
          Text('Age: ${ageText()}   •   Gender: ${genderText()}'),
          Text('Glasses detected in photo: ${glassesText()}'),
          const SizedBox(height: 16),

          // Visual acuity
          const Text(
            'Visual Acuity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Right eye: ${r.right?.snellen ?? '—'} (logMAR ${r.right?.logMAR.toStringAsFixed(2) ?? '—'})',
          ),
          Text(
            'Left eye : ${r.left?.snellen ?? '—'} (logMAR ${r.left?.logMAR.toStringAsFixed(2) ?? '—'})',
          ),
          Text('Overall: ${r.overallLabel}'),
          const SizedBox(height: 16),

          // Assessment
          const Text(
            'Assessment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(r.assessment),
          Text('Warnings: ${r.warning ?? 'None'}'),
          const SizedBox(height: 16),

          // Restart
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Restart'),
          ),

          const SizedBox(height: 16),
          const Text(
            'Disclaimer: Screening only. Not a diagnosis. See an eye care professional for concerns.',
            style: TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }
}
