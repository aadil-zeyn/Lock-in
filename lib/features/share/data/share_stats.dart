import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../dashboard/data/week_summary.dart';
import '../../workout/data/workout_repository.dart';

/// Numbers for the "This week" story card.
class WeekShare {
  const WeekShare({
    required this.weekStart,
    required this.workouts,
    required this.minutes,
    required this.sets,
    required this.volumeKg,
    required this.trainedDays,
    this.topLift,
    this.avgKcal,
    this.weightChangeKg,
  });

  final DateTime weekStart;
  final int workouts;
  final int minutes;
  final int sets;
  final double volumeKg;

  /// Monday..Sunday.
  final List<bool> trainedDays;

  /// Best estimated 1RM this week (weight × reps exercises only).
  final ({String exercise, double e1rmKg})? topLift;

  /// Average kcal on days with food logged this week.
  final int? avgKcal;

  /// Latest weight minus the earliest weigh-in in the last 30 days.
  final double? weightChangeKg;
}

WeekShare computeWeekShare({
  required List<WorkoutDetail> workouts,
  required List<BodyMeasurement> weightsNewestFirst,
  required List<FoodEntry> foodThisWeek,
  required DateTime now,
}) {
  final monday = startOfWeek(now);
  final days = List<bool>.filled(7, false);
  var minutes = 0, sets = 0;
  var volume = 0.0;
  for (final d in workouts) {
    final w = d.workout;
    if (w.startedAt.isBefore(monday)) continue;
    days[w.startedAt.weekday - 1] = true;
    minutes += (w.durationSeconds ?? 0) ~/ 60;
    sets += d.completedSets;
    volume += d.volumeKg;
  }
  final top = bestLift(
    workouts.where((d) => !d.workout.startedAt.isBefore(monday)),
  );

  final perDay = <DateTime, int>{};
  for (final f in foodThisWeek) {
    final day = DateTime(f.loggedAt.year, f.loggedAt.month, f.loggedAt.day);
    perDay[day] = (perDay[day] ?? 0) + f.kcal;
  }

  double? change;
  final since = now.subtract(const Duration(days: 30));
  final recent = weightsNewestFirst
      .where((m) => !m.recordedAt.isBefore(since))
      .toList();
  if (recent.length >= 2) {
    change = recent.first.measuredValue - recent.last.measuredValue;
  }

  return WeekShare(
    weekStart: monday,
    workouts: workouts
        .where((d) => !d.workout.startedAt.isBefore(monday))
        .length,
    minutes: minutes,
    sets: sets,
    volumeKg: volume,
    trainedDays: days,
    topLift: top,
    avgKcal: perDay.isEmpty
        ? null
        : (perDay.values.reduce((a, b) => a + b) / perDay.length).round(),
    weightChangeKg: change,
  );
}

final weekShareProvider = FutureProvider.autoDispose<WeekShare>((ref) async {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(workoutRepositoryProvider);
  final now = DateTime.now();
  final monday = startOfWeek(now);

  final ids =
      await (db.select(db.workouts)..where(
            (w) =>
                w.status.equalsValue(WorkoutStatus.completed) &
                w.startedAt.isBiggerOrEqualValue(monday),
          ))
          .map((w) => w.id)
          .get();
  final details = <WorkoutDetail>[
    for (final id in ids) ?(await repo.loadDetail(id)),
  ];
  final weights =
      await (db.select(db.bodyMeasurements)
            ..where(
              (m) => m.measurementType.equalsValue(MeasurementType.bodyWeight),
            )
            ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)]))
          .get();
  final food = await (db.select(
    db.foodEntries,
  )..where((f) => f.loggedAt.isBiggerOrEqualValue(monday))).get();

  return computeWeekShare(
    workouts: details,
    weightsNewestFirst: weights,
    foodThisWeek: food,
    now: now,
  );
});

/// The most recent completed workout, in full.
final lastWorkoutShareProvider = FutureProvider.autoDispose<WorkoutDetail?>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final latest =
      await (db.select(db.workouts)
            ..where((w) => w.status.equalsValue(WorkoutStatus.completed))
            ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
            ..limit(1))
          .getSingleOrNull();
  if (latest == null) return null;
  return ref.watch(workoutRepositoryProvider).loadDetail(latest.id);
});
