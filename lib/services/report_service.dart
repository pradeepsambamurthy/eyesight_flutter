// lib/services/report_service.dart
import 'dart:math' as math;
import '../models/vision_models.dart' as vm;

/// Internal, lightweight representation of an eye’s acuity used by the report.
class _PseudoAcuity {
  final double logMAR;
  const _PseudoAcuity(this.logMAR);

  String get snellen {
    final denom = (20 * math.pow(10, logMAR)).round();
    return '20/$denom';
  }

  @override
  String toString() => '$snellen (logMAR ${logMAR.toStringAsFixed(2)})';
}

/// Minimal face summary the report needs (decoupled from any ML service type).
class ReportFace {
  final int? age; // estimated or user-provided
  final String? gender; // "Male"/"Female"/"—"
  final bool? wearingGlasses; // detected from photo (optional)

  const ReportFace({this.age, this.gender, this.wearingGlasses});
}

class ReportData {
  // Profile (typed-in)
  String? name;
  int? age;
  String? gender;

  // From photo analysis (optional)
  ReportFace? face;

  // Per-eye acuity for the report
  _PseudoAcuity? right;
  _PseudoAcuity? left;

  // Advisory text (optional)
  String? warning;

  // Convenience getters for UI
  String get overallLabel => _worst?.snellen ?? '—';
  String get assessment =>
      'Right: ${right?.snellen ?? '—'}  •  Left: ${left?.snellen ?? '—'}';

  _PseudoAcuity? get _worst {
    if (right == null && left == null) return null;
    if (left == null) return right;
    if (right == null) return left;
    return right!.logMAR >= left!.logMAR ? right : left;
  }
}

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final ReportData current = ReportData();

  // ---------------- Profile / Demographics ----------------

  /// Called from your capture screen’s text fields.
  void setDemographics({String? name, int? age, String? gender}) {
    current.name = (name == null || name.trim().isEmpty) ? null : name.trim();
    current.age = age;
    current.gender = gender;
  }

  /// Backwards-compat: simple setters if you call them separately.
  void updateName(String? v) =>
      current.name = (v == null || v.trim().isEmpty) ? null : v.trim();
  void updateAge(int? v) => current.age = v;
  void updateGender(String? v) => current.gender = v;

  /// Accept any “face summary” object and map it to our `ReportFace`.
  /// This lets your UI pass the object from FaceService without importing it here.
  void updateFaceSummary(dynamic face) {
    int? age;
    String? gender;
    bool? glasses;

    try {
      final a = face?.age ?? face?.estimatedAge ?? face?.ageYears;
      if (a is num) age = a.toInt();
    } catch (_) {}

    try {
      final g = face?.gender ?? face?.sex;
      if (g is String && g.trim().isNotEmpty) gender = g;
    } catch (_) {}

    try {
      final w = face?.wearingGlasses ?? face?.glasses ?? face?.hasGlasses;
      if (w is bool) glasses = w;
    } catch (_) {}

    current.face = ReportFace(
      age: age,
      gender: gender,
      wearingGlasses: glasses,
    );
  }

  // ---------------- Acuity results ----------------

  /// Always convert incoming results to our report type
  /// and compute an appropriate warning string.
  void updateAcuity(vm.AcuityResult right, vm.AcuityResult left) {
    current.right = _PseudoAcuity(right.logMAR);
    current.left = _PseudoAcuity(left.logMAR);
    current.warning = _buildWarning(right.logMAR, left.logMAR);
  }

  /// If you ever need to clone/normalize the model for the report screen.
  static ReportData normalize(ReportData r) => r;

  // ---------------- Business rules for warnings ----------------

  /// Returns a short user-facing message for the "Warnings" row.
  /// Rules:
  ///  - If either eye is worse than 20/40 (logMAR >= 0.30) → consult doctor.
  ///  - Else if inter-eye difference >= 2 ETDRS lines (≈ 0.20 logMAR) → consider exam.
  ///  - Else → healthy / good vision.
  String _buildWarning(double rLogMar, double lLogMar) {
    const double consultThreshold = 0.30; // ~20/40
    const double anisometropiaGap = 0.20; // ~2 ETDRS lines

    if (rLogMar >= consultThreshold || lLogMar >= consultThreshold) {
      return 'Consult an eye doctor for a detailed exam.';
    }

    if ((rLogMar - lLogMar).abs() >= anisometropiaGap) {
      return 'Consider a professional eye exam (difference between eyes).';
    }

    return 'Your eyes appear healthy with good vision.';
  }
}
