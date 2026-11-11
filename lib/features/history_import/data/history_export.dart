import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/units.dart';
import '../../exercises/data/exercise_repository.dart';

/// Columns of the export, a superset of the History Logger CSV that
/// [parseHistoryCsv] (and the Kotlin app's importer) read.
const exportCsvHeader =
    'date,workout,duration_min,exercise,primary_muscle,equipment,tracking,'
    'set,set_type,weight,unit,reps,seconds,band,cable,resistance,'
    'secondary_muscles,notes';

/// Quotes a field when it contains a comma, quote or line break.
String csvField(String v) =>
    RegExp(r'[,"\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Everything needed to move to another install of Lock-in:
///
/// * one *library row* per custom exercise (empty date, no reps), so
///   exercises that were never logged come across too, with their
///   muscles, equipment, tracking and notes;
/// * one row per ticked set of every completed workout, oldest first.
///
/// Weights are written in kg as entered (assisted assistance unsigned, the
/// importer signs it again). Secondary muscles are `;`-separated.
Future<String> exportHistoryCsv(AppDatabase db) async {
  final out = StringBuffer('$exportCsvHeader\n');
  void row(List<String> cells) => out.writeln(cells.map(csvField).join(','));

  final custom =
      await (db.select(db.exercises)
            ..where((e) => e.isCustom.equals(true) & e.archivedAt.isNull())
            ..orderBy([(e) => OrderingTerm.asc(e.name)]))
          .get();
  for (final e in custom) {
    row([
      '',
      '',
      '',
      e.name,
      e.primaryMuscle.name,
      e.equipment.name,
      e.trackingType.name,
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      e.secondaryMuscleList.map((m) => m.name).join(';'),
      e.description ?? '',
    ]);
  }

  final query =
      db.select(db.workoutSets).join([
          innerJoin(
            db.workoutExercises,
            db.workoutExercises.id.equalsExp(db.workoutSets.workoutExerciseId),
          ),
          innerJoin(
            db.workouts,
            db.workouts.id.equalsExp(db.workoutExercises.workoutId),
          ),
          innerJoin(
            db.exercises,
            db.exercises.id.equalsExp(db.workoutExercises.exerciseId),
          ),
        ])
        ..where(
          db.workouts.status.equalsValue(WorkoutStatus.completed) &
              db.workoutSets.isCompleted.equals(true),
        )
        ..orderBy([
          OrderingTerm.asc(db.workouts.startedAt),
          OrderingTerm.asc(db.workoutExercises.position),
          OrderingTerm.asc(db.workoutSets.setNumber),
        ]);
  for (final r in await query.get()) {
    final w = r.readTable(db.workouts);
    final we = r.readTable(db.workoutExercises);
    final e = r.readTable(db.exercises);
    final s = r.readTable(db.workoutSets);
    final kg = s.weightKg?.abs();
    row([
      _date(w.startedAt),
      w.name,
      w.durationSeconds == null ? '' : '${w.durationSeconds! ~/ 60}',
      we.exerciseNameSnapshot,
      e.primaryMuscle.name,
      e.equipment.name,
      e.trackingType.name,
      '${s.setNumber}',
      s.setType.name,
      kg == null ? '' : formatNumber(kg),
      kg == null ? '' : 'kg',
      s.reps?.toString() ?? '',
      s.durationSeconds?.toString() ?? '',
      s.bandLevel?.name ?? '',
      '',
      '',
      e.secondaryMuscleList.map((m) => m.name).join(';'),
      e.description ?? '',
    ]);
  }
  return out.toString();
}
