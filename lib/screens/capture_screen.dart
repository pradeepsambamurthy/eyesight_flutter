// lib/screens/capture_screen.dart
import 'package:flutter/material.dart';
import '../services/report_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  String? _gender; // <-- replaces the missing _selectedGender
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _startTest() {
    // Save demographics to the shared report service
    ReportService.instance.setDemographics(
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text.trim()),
      gender: _gender,
    );

    // Go to the acuity test screen (adjust route if your app uses a different one)
    Navigator.pushNamed(context, '/acuity');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start / Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age (years, optional)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 1 || n > 120) {
                  return 'Enter a valid age (1–120) or leave blank';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text('Other / Prefer not to say'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Gender (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _gender = val),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                if (_formKey.currentState?.validate() != true) return;
                _startTest();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Visual Acuity Test'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: You can wear your usual glasses if you normally use them.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
