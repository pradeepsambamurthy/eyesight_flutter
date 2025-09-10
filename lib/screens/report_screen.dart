// lib/screens/report_screen.dart
import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../models/vision_models.dart' as vm; // for TestMode

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = ReportService.normalize(ReportService.instance.current);

    // Figure out what the previous screen told us
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final completed =
        args?['completed'] as vm.TestMode? ?? vm.TestMode.distance;
    final nextMode = completed == vm.TestMode.distance
        ? vm.TestMode.near
        : vm.TestMode.distance;

    // Prefer typed-in age/gender, fall back to face estimation
    final name = (r.name?.trim().isNotEmpty == true) ? r.name : '—';
    final age = r.age ?? r.face?.age;
    final gender = r.gender ?? r.face?.gender;
    final glassesDetected = r.face?.wearingGlasses == true
        ? 'Yes'
        : 'No/Unknown';

    final hasDistance = r.hasDistance;
    final hasNear = r.hasNear;
    final bothDone = hasDistance && hasNear;

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

          // Visual Acuity (primary — shows Distance if present, else Near)
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

          // Optional: show both Distance & Near when available
          if (bothDone) ...[
            const SizedBox(height: 12),
            Text(
              'Distance vs Near',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance — Right: ${r.distanceRight?.snellen ?? '—'}'
                      '${r.distanceRight == null ? '' : ' (logMAR ${r.distanceRight!.logMAR.toStringAsFixed(2)})'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Distance — Left : ${r.distanceLeft?.snellen ?? '—'}'
                      '${r.distanceLeft == null ? '' : ' (logMAR ${r.distanceLeft!.logMAR.toStringAsFixed(2)})'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Near — Right: ${r.nearRight?.snellen ?? '—'}'
                      '${r.nearRight == null ? '' : ' (logMAR ${r.nearRight!.logMAR.toStringAsFixed(2)})'}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Near — Left : ${r.nearLeft?.snellen ?? '—'}'
                      '${r.nearLeft == null ? '' : ' (logMAR ${r.nearLeft!.logMAR.toStringAsFixed(2)})'}',
                    ),
                  ],
                ),
              ),
            ),
          ],

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

          // Primary action: go to the NEXT test
          FilledButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                '/test',
                arguments: {'mode': nextMode},
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(
              nextMode == vm.TestMode.near
                  ? 'Continue: Near Test'
                  : 'Continue: Distance Test',
            ),
          ),

          // Optional secondary: start over (clears saved results)
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ReportService.instance.resetAll();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Start Over'),
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
