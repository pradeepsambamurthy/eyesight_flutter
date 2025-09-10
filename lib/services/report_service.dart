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

  // Advisory text (user-facing)
  String? warning;

  // NEW: Age classification + age-adjusted assessment + refractive hint
  String? ageGroupLabel; // e.g., "Child (6–12)", "Adult (18–39)"
  String?
  ageAdjustedVerdict; // e.g., "Within normal for age" / "Refer (below age norms)"
  String? refractiveHint; // e.g., "Likely short-sight (myopia)"

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

  // ---------------- Acuity results + derived assessments ----------------

  /// Convert incoming results and compute warnings + age-adjusted assessment + refractive hint.
  void updateAcuity(vm.AcuityResult right, vm.AcuityResult left) {
    current.right = _PseudoAcuity(right.logMAR);
    current.left = _PseudoAcuity(left.logMAR);

    final r = right.logMAR;
    final l = left.logMAR;
    current.warning = _buildWarning(r, l);

    // Age classification & age-adjusted verdict
    final age = current.age ?? current.face?.age;
    final worst = (r >= l) ? r : l;
    final diff = (r - l).abs();

    final ageInfo = _ageClassAndThreshold(age);
    current.ageGroupLabel = ageInfo.label;
    current.ageAdjustedVerdict = _ageAdjustedVerdict(
      worst,
      diff,
      ageInfo.passThresholdLogMAR,
    );

    // Refractive hint based on patterns (distance-only approximation)
    current.refractiveHint = _refractiveHint(worst, diff, age);
  }

  /// If you ever need to clone/normalize the model for the report screen.
  static ReportData normalize(ReportData r) => r;

  // ---------------- Business rules ----------------

  /// Warnings row (simple & clear, distance test only).
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

  // ---- Age classification & thresholds ----

  /// Age class + pass threshold for distance acuity (logMAR).
  /// These are screening-style, not diagnostic. Tweak as you like.
  _AgeInfo _ageClassAndThreshold(int? age) {
    if (age == null) {
      // Use adult defaults if unknown
      return const _AgeInfo('Adult (18–59)', 0.20); // ~20/32
    }
    if (age <= 5) return const _AgeInfo('Under 6 (not supported)', 0.20);
    if (age <= 12) return const _AgeInfo('Child (6–12)', 0.18); // ~20/30
    if (age <= 17) return const _AgeInfo('Teen (13–17)', 0.20); // ~20/32
    if (age <= 39) return const _AgeInfo('Adult (18–39)', 0.20); // ~20/32
    if (age <= 59) return const _AgeInfo('Adult (40–59)', 0.20); // ~20/32
    return const _AgeInfo('Older adult (60+)', 0.30); // ~20/40
  }

  String _ageAdjustedVerdict(
    double worstLogMAR,
    double interEyeDiff,
    double passThreshold,
  ) {
    if (worstLogMAR <= passThreshold) {
      return 'Within normal range for age';
    }
    return 'Refer (below age norms)';
  }

  // ---- Refractive pattern hint (distance-only approximation) ----

  /// Very simple hint based on distance acuity and age.
  /// - Poor distance acuity (≥20/40) → likely short-sight (myopia).
  /// - Big inter-eye gap → anisometropia/astigmatism risk.
  /// - Age ≥45 with normal distance → near-vision difficulty common (presbyopia).
  String _refractiveHint(double worstLogMAR, double interEyeDiff, int? age) {
    const double myopiaCut = 0.30; // ~20/40
    const double bigGap = 0.20; // ~2 ETDRS lines

    if (interEyeDiff >= bigGap) {
      return 'Difference between eyes is notable — possible astigmatism or anisometropia.';
    }
    if (worstLogMAR >= myopiaCut) {
      return 'Likely short-sight (myopia) — distance vision reduced.';
    }
    if ((age ?? 0) >= 45) {
      return 'Distance is OK. If near reading is hard, age-related long-sight (presbyopia) is common.';
    }
    return 'No strong refractive pattern from distance screening alone.';
  }
}

class _AgeInfo {
  final String label;
  final double passThresholdLogMAR;
  const _AgeInfo(this.label, this.passThresholdLogMAR);
}
