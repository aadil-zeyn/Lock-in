import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

class HistoryItem {
  const HistoryItem(this.workout, this.exercises, this.sets);
  final Workout workout;
  final int exercises;

  /// Completed sets.
  final int sets;
}

/// Completed workouts, newest first, with exercise and set counts.
/// Re-emits whenever workouts, their exercises or sets change.
final workoutHistoryProvider = StreamProvider<List<HistoryItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT w.id AS id, COUNT(DISTINCT we.id) AS ex, '
        'COALESCE(SUM(CASE WHEN s.is_completed = 1 THEN 1 ELSE 0 END), 0) AS sets '
        'FROM workouts w '
        'LEFT JOIN workout_exercises we ON we.workout_id = w.id '
        'LEFT JOIN workout_sets s ON s.workout_exercise_id = we.id '
        "WHERE w.status = 'completed' "
        'GROUP BY w.id',
        readsFrom: {db.workouts, db.workoutExercises, db.workoutSets},
      )
      .watch()
      .asyncMap((rows) async {
        final counts = {
          for (final r in rows)
            r.read<int>('id'): (r.read<int>('ex'), r.read<int>('sets')),
        };
        final workouts = await (db.select(
          db.workouts,
        )..where((w) => w.id.isIn(counts.keys))).get();
        workouts.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return [
          for (final w in workouts)
            HistoryItem(w, counts[w.id]!.$1, counts[w.id]!.$2),
        ];
      });
});
