import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_format.dart';

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

/// Completed working sets (warm-ups excluded) in completed workouts this week.
final thisWeekSetsProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final since = startOfWeek(DateTime.now());
  final count = db.workoutSets.id.count();
  final query =
      db.selectOnly(db.workoutSets).join([
          innerJoin(
            db.workoutExercises,
            db.workoutExercises.id.equalsExp(db.workoutSets.workoutExerciseId),
          ),
          innerJoin(
            db.workouts,
            db.workouts.id.equalsExp(db.workoutExercises.workoutId),
          ),
        ])
        ..addColumns([count])
        ..where(
          db.workoutSets.isCompleted.equals(true) &
              db.workoutSets.setType.equalsValue(SetType.warmup).not() &
              db.workouts.status.equalsValue(WorkoutStatus.completed) &
              db.workouts.startedAt.isBiggerOrEqualValue(since),
        );
  return query.map((row) => row.read(count) ?? 0).watchSingle();
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
