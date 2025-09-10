import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/face_service.dart' as faces;
import '../services/report_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Inputs
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String? _gender; // "Male" | "Female" | "Non-binary" | "Prefer not to say"

  // Image + optional face summary
  File? _image;
  faces.FaceSummary? _face; // optional (may be null)
  String? _hint;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from any existing report data (safe if null)
    final r = ReportService.instance.current;
    if (r.name != null) _nameCtrl.text = r.name!;
    if (r.age != null) _ageCtrl.text = '${r.age}';
    _gender = r.gender; // keep null if not set
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _hint = null;
    });

    try {
      final x = await _picker.pickImage(source: src, imageQuality: 95);
      if (x == null) return;
      final file = File(x.path);

      final face = await faces.FaceService.instance
          .analyze(file)
          .catchError((_) => null);

      setState(() {
        _image = file;
        _face = face;
        _hint = face == null
            ? 'Face analysis unavailable (no model). You can still continue.'
            : 'Detected (approx): age ${face.age ?? '—'}, gender ${face.gender ?? '—'}, glasses ${face.wearingGlasses == true ? 'yes' : 'no/unknown'}.';
      });

      // (Optional) seed report with detected summary — user-entered values still win
      ReportService.instance.updateFaceSummary(face);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTest() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    final gender = _gender;

    // Persist to the report profile
    ReportService.instance.setDemographics(
      name: name,
      age: age,
      gender: gender,
    );

    Navigator.pushNamed(context, '/test');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture or Pick Photo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 12),

                // Age + Gender row
                Row(
                  children: [
                    // Age
                    Expanded(
                      child: TextFormField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Age required';
                          final n = int.tryParse(v);
                          if (n == null || n < 1 || n > 120)
                            return 'Enter 1–120';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Gender
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'Non-binary',
                            child: Text('Non-binary'),
                          ),
                          DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.transgender),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _gender = v),
                        validator: (v) => v == null ? 'Please select' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Capture / Gallery
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Preview
                AspectRatio(
                  aspectRatio: 3 / 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _image == null
                        ? Container(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: const Center(
                              child: Text('Take or choose a photo (optional).'),
                            ),
                          )
                        : Image.file(_image!, fit: BoxFit.cover),
                  ),
                ),

                const SizedBox(height: 8),
                if (_hint != null) Text(_hint!, textAlign: TextAlign.center),

                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _startTest,
                  child: const Text('Start Visual Acuity Test'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Disclaimer: Screening only. Not a diagnosis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
