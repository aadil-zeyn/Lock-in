import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../food/data/food_repository.dart';
import '../../../core/utils/units.dart';
import '../../health/data/health_providers.dart';
import '../../workout/data/workout_repository.dart';

/// 1 for 1 January. UTC dates so a DST change can't shift the count.
int dayOfYear(DateTime d) =>
    DateTime.utc(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime.utc(d.year, 1, 1)).inDays +
    1;

int daysInYear(int year) =>
    DateTime.utc(year + 1, 1, 1).difference(DateTime.utc(year, 1, 1)).inDays;

/// Consecutive days at or above [goal], ending today. Today only counts
/// once reached; until then the streak runs to yesterday.
int stepsStreak(List<int> stepsOldestFirst, int goal) {
  if (stepsOldestFirst.isEmpty || goal <= 0) return 0;
  var i = stepsOldestFirst.length - 1;
  if (stepsOldestFirst[i] < goal) i--; // today still in progress
  var n = 0;
  for (; i >= 0 && stepsOldestFirst[i] >= goal; i--) {
    n++;
  }
  return n;
}

/// Whether today's calories match the goal: at most ~target when losing,
/// at least ~target when gaining, within ±10% when maintaining.
bool caloriesOnTarget(int eaten, int target, WeightGoal? goal) {
  if (eaten <= 0 || target <= 0) return false;
  final r = eaten / target;
  return switch (goal) {
    WeightGoal.lose => r >= 0.7 && r <= 1.05,
    WeightGoal.gain => r >= 0.95,
    _ => r >= 0.9 && r <= 1.1,
  };
}

/// One-line summary of an exercise's working sets, e.g. "3 × 8 · 60 kg",
/// "3 × 8–10 · 60 kg", "3 × 12", "3 × 45 s", "3 × 15 · Heavy".
/// Warm-ups and unticked sets are left out. Null when nothing was done.
String? summarizeSets(
  List<WorkoutSet> sets,
  TrackingType tracking,
  WeightUnit unit,
) {
  final done = [
    for (final s in sets)
      if (s.isCompleted && s.setType.countsTowardStats) s,
  ];
  if (done.isEmpty) return null;
  final n = done.length;

  String range(Iterable<int> values) {
    final v = values.toList()..sort();
    return v.first == v.last ? '${v.first}' : '${v.first}–${v.last}';
  }

  switch (tracking) {
    case TrackingType.duration:
      final secs = done.map((s) => s.durationSeconds ?? 0).where((x) => x > 0);
      return secs.isEmpty ? '$n sets' : '$n × ${range(secs)} s';
    case TrackingType.bandReps:
      final reps = done.map((s) => s.reps ?? 0).where((x) => x > 0);
      final bands = done.map((s) => s.bandLevel).whereType<BandLevel>();
      final heaviest = bands.isEmpty
          ? null
          : bands.reduce((a, b) => a.index >= b.index ? a : b);
      final base = reps.isEmpty ? '$n sets' : '$n × ${range(reps)}';
      return heaviest == null ? base : '$base · ${heaviest.label}';
    case TrackingType.weightReps:
    case TrackingType.bodyweightReps:
    case TrackingType.assistedBodyweight:
      final reps = done.map((s) => s.reps ?? 0).where((x) => x > 0);
      final base = reps.isEmpty ? '$n sets' : '$n × ${range(reps)}';
      final weights = done
          .map((s) => s.weightKg ?? 0)
          .where((w) => w != 0)
          .map((w) => w.abs());
      if (weights.isEmpty) return base;
      final top = weights.reduce((a, b) => a > b ? a : b);
      final shown = kgToDisplay(top, unit);
      final txt = shown == shown.roundToDouble()
          ? shown.toStringAsFixed(0)
          : shown.toStringAsFixed(1);
      final sign = switch (tracking) {
        TrackingType.bodyweightReps => '+',
        TrackingType.assistedBodyweight => '−',
        _ => '',
      };
      return '$base · $sign$txt ${unit == WeightUnit.kg ? 'kg' : 'lb'}';
  }
}

/// Rough walking distance from steps: stride ≈ 41.5% of height,
/// 0.76 m when the height isn't set. Shown with "≈" — it's an estimate.
double estimateDistanceKm(int steps, double? heightCm) {
  final strideM = heightCm == null || heightCm <= 0
      ? 0.76
      : heightCm * 0.415 / 100;
  return steps * strideM / 1000;
}

class DayCardData {
  const DayCardData({
    required this.date,
    required this.steps,
    required this.stepsGoal,
    required this.streak,
    required this.workoutName,
    required this.proteinG,
    required this.proteinGoal,
    required this.kcal,
    required this.kcalGoal,
    required this.kcalOk,
    this.exercises = const [],
    this.workoutMinutes,
    this.workoutSets = 0,
    this.stepsWeek,
    this.heightCm,
  });

  final DateTime date;

  /// Null when Health Connect isn't connected.
  final int? steps;
  final int stepsGoal;
  final int streak;

  /// Today's workout (finished or in progress), or null for a rest day.
  final String? workoutName;
  final int proteinG;
  final int proteinGoal;
  final int kcal;
  final int kcalGoal;
  final bool kcalOk;

  /// Today's exercises with a one-line set summary, in workout order.
  final List<({String name, String summary})> exercises;

  /// Length of today's workout (elapsed so far if still running).
  final int? workoutMinutes;

  /// Completed working sets in today's workout (warm-ups excluded).
  final int workoutSets;

  /// Steps for the last 7 days, oldest first, today last. Null when
  /// Health Connect isn't connected.
  final List<int>? stepsWeek;

  final double? heightCm;

  bool get isRestDay => workoutName == null;

  int get day => dayOfYear(date);
  int get yearDays => daysInYear(date.year);
  bool get stepsOk => (steps ?? 0) >= stepsGoal;
  bool get workoutOk => workoutName != null;
  bool get proteinOk => proteinGoal > 0 && proteinG >= proteinGoal;

  /// 0..1 towards the steps goal.
  double get stepsProgress => steps == null || stepsGoal <= 0
      ? 0
      : (steps! / stepsGoal).clamp(0.0, 1.0);

  double? get distanceKm =>
      steps == null ? null : estimateDistanceKm(steps!, heightCm);
}

final dayCardProvider = FutureProvider.autoDispose<DayCardData>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final profile = await (db.select(
    db.userProfiles,
  )..where((p) => p.id.equals(1))).getSingle();
  final stepsGoal = profile.dailyStepsGoal;
  final history = await ref.watch(stepsHistoryProvider(120).future);
  final stepsList = history?.map((d) => d.steps).toList();

  final workout =
      await (db.select(db.workouts)
            ..where(
              (w) =>
                  w.status.isNotValue(WorkoutStatus.discarded.name) &
                  w.startedAt.isBiggerOrEqualValue(today),
            )
            ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
            ..limit(1))
          .getSingleOrNull();

  final detail = workout == null
      ? null
      : await ref.watch(workoutRepositoryProvider).loadDetail(workout.id);
  final exercises = <({String name, String summary})>[
    for (final e in detail?.exercises ?? const <WorkoutExerciseDetail>[])
      if (summarizeSets(e.sets, e.exercise.trackingType, profile.weightUnit)
          case final s?)
        (name: e.name, summary: s),
  ];

  final food = totalsFor(
    await (db.select(
      db.foodEntries,
    )..where((f) => f.loggedAt.isBiggerOrEqualValue(today))).get(),
  );

  return DayCardData(
    date: now,
    steps: stepsList?.last,
    stepsGoal: stepsGoal,
    streak: stepsList == null ? 0 : stepsStreak(stepsList, stepsGoal),
    workoutName: workout?.name,
    proteinG: food.proteinG.round(),
    proteinGoal: profile.dailyProteinGoal,
    kcal: food.kcal,
    kcalGoal: profile.dailyKcalGoal,
    kcalOk: caloriesOnTarget(
      food.kcal,
      profile.dailyKcalGoal,
      profile.weightGoal,
    ),
    exercises: exercises,
    workoutSets: [
      for (final e in detail?.exercises ?? const <WorkoutExerciseDetail>[])
        for (final s in e.sets)
          if (s.isCompleted && s.setType.countsTowardStats) s,
    ].length,
    stepsWeek: stepsList?.sublist(
      stepsList.length < 7 ? 0 : stepsList.length - 7,
    ),
    heightCm: profile.heightCm,
    workoutMinutes: workout == null
        ? null
        : workout.status == WorkoutStatus.active
        ? now.difference(workout.startedAt).inMinutes
        : (workout.durationSeconds ?? 0) ~/ 60,
  );
});
