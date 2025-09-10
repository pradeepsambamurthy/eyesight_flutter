// lib/screens/acuity_test_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';

// Namespaced models (enums + result types)
import '../models/vision_models.dart' as vm;

// Only the service class to avoid type clashes
import '../services/acuity_service.dart' show AcuityService;
import '../services/calibration_service.dart';
import '../services/compliance_service.dart';
import '../services/report_service.dart';

class AcuityTestScreen extends StatefulWidget {
  const AcuityTestScreen({super.key});
  @override
  State<AcuityTestScreen> createState() => _AcuityTestScreenState();
}

class _AcuityTestScreenState extends State<AcuityTestScreen> {
  final _acuity = AcuityService.instance;
  final _calib = CalibrationService.instance;
  final _comp = ComplianceService.instance;

  // Which test are we running: distance or near?
  late vm.TestMode _mode;

  vm.CalibrationResult? _cal;
  vm.EyeSide _eye = vm.EyeSide.right;
  vm.AcuityResult? _r, _l;
  bool _started = false;

  String get _introStatus => _mode == vm.TestMode.near
      ? 'Hold device ~40cm/16in away. Cover LEFT eye.'
      : 'Stand ~3m/10ft from screen. Cover LEFT eye.';

  String _status = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    // Expect arguments like: {'mode': vm.TestMode.near}
    _mode = (args is Map && args['mode'] is vm.TestMode)
        ? args['mode'] as vm.TestMode
        : vm.TestMode.distance; // default if nothing passed
    _status = _introStatus;
  }

  Future<void> _begin() async {
    _cal = await _calib.quickDefaults(mode: _mode);
    await _acuity.start(eye: _eye, calibration: _cal!); // start with RIGHT eye
    setState(() => _started = true);
  }

  /// Convert whatever the service returns into our vm.AcuityResult
  vm.AcuityResult _toVmResult(dynamic raw) {
    if (raw is vm.AcuityResult) return raw;
    try {
      final value = raw?.logMAR ?? raw?.logmar ?? raw?.logmarValue;
      if (value is num) return vm.AcuityResult(value.toDouble());
    } catch (_) {}
    return const vm.AcuityResult(0.3); // conservative fallback (~20/40)
  }

  /// User tapped "I read it" (continues staircase; finishes only at stop rule)
  Future<void> _onCouldRead() async {
    final finished = _acuity.submitAnswer(true);
    setState(() {});
    if (!finished) return;

    final vm.AcuityResult res = _toVmResult(_acuity.finish());
    await _handleEyeDone(res);
  }

  /// User tapped "Couldn't read" (immediately finalize current eye)
  Future<void> _onCouldNotRead() async {
    final vm.AcuityResult res = _toVmResult(_acuity.finish());
    await _handleEyeDone(res);
  }

  Future<void> _handleEyeDone(vm.AcuityResult res) async {
    if (_eye == vm.EyeSide.right) {
      _r = res;
      _eye = vm.EyeSide.left;
      _status = _mode == vm.TestMode.near
          ? 'Now cover RIGHT eye. Keep ~40cm/16in distance.'
          : 'Now cover RIGHT eye. Keep 3m/10ft distance.';
      await _acuity.start(eye: _eye, calibration: _cal!);
      setState(() {});
    } else {
      _l = res;

      // Save the results tagged by mode so the report can compare distance vs near
      ReportService.instance.updateAcuityModeAware(
        mode: _mode,
        right: _r ?? const vm.AcuityResult(0.3),
        left: _l ?? const vm.AcuityResult(0.3),
      );

      if (mounted) {
        // Tell the report which test just completed so it can offer "Continue: <next>"
        Navigator.pushReplacementNamed(
          context,
          '/report',
          arguments: {'completed': _mode},
        );
      }
    }
  }

  // Optional compliance check (not wired to UI yet)
  // ignore: unused_element
  Future<void> _checkCompliance(File lastFrame) async {
    if (_cal == null) return;
    final flags = await _comp.analyzeFrame(
      lastFrame,
      _eye,
      targetDistanceCm: _cal!.targetDistanceCm,
    );
    if (flags == null) return;
    if (!flags.goodLighting) setState(() => _status = 'Increase room lighting');
    if (!flags.distanceLocked)
      setState(() => _status = 'Please keep the same distance');
    if (_eye == vm.EyeSide.right && !flags.leftEyeCovered)
      setState(() => _status = 'Cover LEFT eye');
    if (_eye == vm.EyeSide.left && !flags.rightEyeCovered)
      setState(() => _status = 'Cover RIGHT eye');
  }

  @override
  Widget build(BuildContext context) {
    final title = _mode == vm.TestMode.near
        ? 'Acuity Test (Near)'
        : 'Acuity Test (Distance)';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !_started
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calibration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_introStatus),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _begin,
                    child: const Text('Start Right Eye'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_status),
                  const SizedBox(height: 8),
                  Text(
                    'Testing ${_eye == vm.EyeSide.right ? 'RIGHT' : 'LEFT'} eye',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(child: _acuity.currentWidget(context)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _onCouldRead,
                          icon: const Icon(Icons.check),
                          label: const Text('I read it'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _onCouldNotRead,
                          icon: const Icon(Icons.close),
                          label: const Text("Couldn't read"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
