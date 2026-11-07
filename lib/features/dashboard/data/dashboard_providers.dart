import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../workout/data/workout_repository.dart';
import 'week_summary.dart';

/// The in-progress workout, if any (at most one, enforced by the DB).
final activeWorkoutProvider = StreamProvider<Workout?>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.workouts)
    ..where((w) => w.status.equalsValue(WorkoutStatus.active))
    ..limit(1);
  return query.watchSingleOrNull();
});

/// Completed workouts since Monday of the current week.
final thisWeekWorkoutsProvider = StreamProvider<List<Workout>>((ref) {
  final db = ref.watch(databaseProvider);
  final since = startOfWeek(DateTime.now());
  final query = db.select(db.workouts)
    ..where(
      (w) =>
          w.status.equalsValue(WorkoutStatus.completed) &
          w.startedAt.isBiggerOrEqualValue(since),
    )
    ..orderBy([(w) => OrderingTerm.desc(w.startedAt)]);
  return query.watch();
});

final latestWorkoutProvider = StreamProvider<Workout?>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.workouts)
    ..where((w) => w.status.equalsValue(WorkoutStatus.completed))
    ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
    ..limit(1);
  return query.watchSingleOrNull();
});

/// Latest two body-weight entries (newest first) so we can show the change.
final recentBodyWeightsProvider = StreamProvider<List<BodyMeasurement>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.bodyMeasurements)
    ..where((m) => m.measurementType.equalsValue(MeasurementType.bodyWeight))
    ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)])
    ..limit(2);
  return query.watch();
});

final userProfileProvider = StreamProvider<UserProfile>((ref) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.userProfiles)..where((p) => p.id.equals(1));
  return query.watchSingle();
});

/// This week vs last week, per-day detail and best lift for the Home card.
/// Re-computes whenever workouts or their sets change.
final weekSummaryProvider = StreamProvider<WeekSummary>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(workoutRepositoryProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.workouts,
          db.workoutExercises,
          db.workoutSets,
          db.exercises,
        },
      )
      .watch()
      .asyncMap((_) async {
        final now = DateTime.now();
        final since = startOfWeek(
          startOfWeek(now).subtract(const Duration(days: 1)),
        );
        final ids =
            await (db.select(db.workouts)..where(
                  (w) =>
                      w.status.equalsValue(WorkoutStatus.completed) &
                      w.startedAt.isBiggerOrEqualValue(since),
                ))
                .map((w) => w.id)
                .get();
        final details = <WorkoutDetail>[
          for (final id in ids) ?(await repo.loadDetail(id)),
        ];
        return computeWeekSummary(workouts: details, now: now);
      });
});

/// Weeks in a row the weekly workout goal was hit (see [weekStreak]).
final weekStreakProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final goal = ref.watch(
    userProfileProvider.select((p) => p.value?.weeklyWorkoutGoal ?? 3),
  );
  final query = db.selectOnly(db.workouts)
    ..addColumns([db.workouts.startedAt])
    ..where(db.workouts.status.equalsValue(WorkoutStatus.completed));
  return query
      .map((row) => row.read(db.workouts.startedAt)!)
      .watch()
      .map(
        (starts) =>
            weekStreak(workoutStarts: starts, goal: goal, now: DateTime.now()),
      );
});

/// Saves the three weekly ring goals.
Future<void> setWeeklyGoals(
  AppDatabase db, {
  required int workouts,
  required int minutes,
  required int sets,
}) async {
  await (db.update(db.userProfiles)..where((p) => p.id.equals(1))).write(
    UserProfilesCompanion(
      weeklyWorkoutGoal: Value(workouts),
      weeklyMinutesGoal: Value(minutes),
      weeklySetsGoal: Value(sets),
      updatedAt: Value(DateTime.now()),
    ),
  );
}
