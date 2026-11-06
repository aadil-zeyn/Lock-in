import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

typedef ExerciseFilter = ({
  String query,
  MuscleGroup? muscle,
  Equipment? equipment,
  bool archived,
});

/// Exercises matching a search query and optional muscle/equipment.
/// [ExerciseFilter.archived] switches between the library and the archive.
final exerciseListProvider = StreamProvider.autoDispose
    .family<List<Exercise>, ExerciseFilter>((ref, filter) {
      final db = ref.watch(databaseProvider);
      final query = db.select(db.exercises)
        ..where(
          (e) => filter.archived
              ? e.archivedAt.isNotNull()
              : e.archivedAt.isNull(),
        );

      final text = filter.query.trim();
      if (text.isNotEmpty) {
        // Every word must match somewhere: "db press" finds "Dumbbell Bench Press"
        // only if both words appear, so search stays predictable.
        for (final word in text.split(RegExp(r'\s+'))) {
          query.where((e) => e.name.like('%$word%'));
        }
      }
      if (filter.muscle != null) {
        query.where((e) => e.primaryMuscle.equalsValue(filter.muscle));
      }
      if (filter.equipment != null) {
        query.where((e) => e.equipment.equalsValue(filter.equipment));
      }
      query.orderBy([(e) => OrderingTerm.asc(e.name)]);
      return query.watch();
    });

/// One exercise by id, archived or not (history links need both).
final exerciseProvider = StreamProvider.autoDispose.family<Exercise?, int>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.exercises,
  )..where((e) => e.id.equals(id))).watchSingleOrNull();
});

/// How many times an exercise appears in completed workouts.
final exerciseUsageProvider = StreamProvider.autoDispose.family<int, int>((
  ref,
  exerciseId,
) {
  final db = ref.watch(databaseProvider);
  final count = db.workoutExercises.id.count();
  final query =
      db.selectOnly(db.workoutExercises).join([
          innerJoin(
            db.workouts,
            db.workouts.id.equalsExp(db.workoutExercises.workoutId),
          ),
        ])
        ..addColumns([count])
        ..where(
          db.workoutExercises.exerciseId.equals(exerciseId) &
              db.workouts.status.equalsValue(WorkoutStatus.completed),
        );
  return query.map((row) => row.read(count) ?? 0).watchSingle();
});
