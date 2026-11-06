/// Strength calculations. Rules are documented in docs/PRD-v1.1-changes.md §2.
library;

/// Epley estimated one-rep max. Returns null outside 1–12 reps,
/// where the estimate stops being meaningful.
double? estimateOneRepMax(double weightKg, int reps) {
  if (weightKg <= 0 || reps < 1 || reps > 12) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// Volume for one set (kg × reps). Null-safe; missing values contribute 0.
double setVolume(double? weightKg, int? reps) {
  if (weightKg == null || reps == null || weightKg <= 0 || reps <= 0) {
    return 0;
  }
  return weightKg * reps;
}

/// Effective load for bodyweight-style movements.
/// [addedKg] is extra weight (belt) or, for assisted machines, a negative
/// number equal to the assistance.
double? effectiveBodyweightLoad(double? bodyWeightKg, double addedKg) {
  if (bodyWeightKg == null) return null;
  final load = bodyWeightKg + addedKg;
  return load > 0 ? load : 0;
}
