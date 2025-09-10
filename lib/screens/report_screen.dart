// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import '../services/report_service.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = ReportService.normalize(ReportService.instance.current);

    // Prefer typed-in age/gender, fall back to face estimation
    final name = (r.name?.trim().isNotEmpty == true) ? r.name : '—';
    final age = r.age ?? r.face?.age;
    final gender = r.gender ?? r.face?.gender;
    final glassesDetected = r.face?.wearingGlasses == true
        ? 'Yes'
        : 'No/Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Your Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile
          Text('Profile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: $name'),
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${age?.toString() ?? '—'}   •   Gender: ${gender ?? '—'}',
                  ),
                  const SizedBox(height: 4),
                  Text('Glasses detected in photo: $glassesDetected'),
                  if (r.ageGroupLabel != null) ...[
                    const SizedBox(height: 8),
                    Text('Age group: ${r.ageGroupLabel}'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Visual Acuity
          Text('Visual Acuity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Right eye: ${r.right?.snellen ?? '—'} '
                    '(${r.right == null ? '' : 'logMAR ${r.right!.logMAR.toStringAsFixed(2)}'})',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Left eye : ${r.left?.snellen ?? '—'} '
                    '(${r.left == null ? '' : 'logMAR ${r.left!.logMAR.toStringAsFixed(2)}'})',
                  ),
                  const SizedBox(height: 8),
                  Text('Overall: ${r.overallLabel}'),
                  if (r.ageAdjustedVerdict != null) ...[
                    const SizedBox(height: 4),
                    Text('Age-adjusted: ${r.ageAdjustedVerdict}'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Assessment
          Text('Assessment', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.assessment),
                  const SizedBox(height: 8),
                  Text('Warnings: ${r.warning ?? 'None'}'),
                  if (r.refractiveHint != null) ...[
                    const SizedBox(height: 8),
                    Text('Refractive hint: ${r.refractiveHint}'),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/report',
              (route) => false,
            ),
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
