import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../body/data/body_repository.dart';
import 'stats.dart';

/// Body-weight entries (kg) as chart points, oldest first.
final weightPointsProvider = Provider<AsyncValue<List<ChartPoint>>>((ref) {
  return ref
      .watch(bodyWeightHistoryProvider)
      .whenData(
        (rows) => [
          for (final m in rows.reversed) (x: m.recordedAt, y: m.measuredValue),
        ],
      );
});

/// Completed workouts in the last 8 weeks, bucketed per week.
final weeklyTrainingProvider = StreamProvider<List<WeekTraining>>((ref) {
  final db = ref.watch(databaseProvider);
  final since = DateTime.now().subtract(const Duration(days: 7 * 9));
  return (db.select(db.workouts)..where(
        (w) =>
            w.status.equalsValue(WorkoutStatus.completed) &
            w.startedAt.isBiggerOrEqualValue(since),
      ))
      .watch()
      .map((list) => weeklyTraining(list, DateTime.now()));
});

/// Exercises with at least one completed set, most-logged first.
final loggedExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  final count = db.workoutSets.id.count();
  final query =
      db.select(db.exercises).join([
          innerJoin(
            db.workoutExercises,
            db.workoutExercises.exerciseId.equalsExp(db.exercises.id),
          ),
          innerJoin(
            db.workouts,
            db.workouts.id.equalsExp(db.workoutExercises.workoutId),
          ),
          innerJoin(
            db.workoutSets,
            db.workoutSets.workoutExerciseId.equalsExp(db.workoutExercises.id),
          ),
        ])
        ..addColumns([count])
        ..where(
          db.workouts.status.equalsValue(WorkoutStatus.completed) &
              db.workoutSets.isCompleted.equals(true),
        )
        ..groupBy([db.exercises.id])
        ..orderBy([OrderingTerm.desc(count)]);
  return query.watch().map(
    (rows) => [for (final r in rows) r.readTable(db.exercises)],
  );
});

/// One point per completed workout for [exerciseId] (see [exerciseProgress]).
final exerciseProgressProvider = StreamProvider.autoDispose
    .family<List<ChartPoint>, ({int exerciseId, ProgressMetric metric})>((
      ref,
      key,
    ) {
      final db = ref.watch(databaseProvider);
      final query =
          db.select(db.workoutSets).join([
            innerJoin(
              db.workoutExercises,
              db.workoutExercises.id.equalsExp(
                db.workoutSets.workoutExerciseId,
              ),
            ),
            innerJoin(
              db.workouts,
              db.workouts.id.equalsExp(db.workoutExercises.workoutId),
            ),
          ])..where(
            db.workoutExercises.exerciseId.equals(key.exerciseId) &
                db.workouts.status.equalsValue(WorkoutStatus.completed) &
                db.workoutSets.isCompleted.equals(true),
          );
      return query.watch().map((rows) {
        final sets = [
          for (final r in rows)
            (
              date: r.readTable(db.workouts).startedAt,
              workoutId: r.readTable(db.workouts).id,
              type: r.readTable(db.workoutSets).setType,
              weightKg: r.readTable(db.workoutSets).weightKg,
              reps: r.readTable(db.workoutSets).reps,
              seconds: r.readTable(db.workoutSets).durationSeconds,
            ),
        ];
        return exerciseProgress(sets, key.metric);
      });
    });
