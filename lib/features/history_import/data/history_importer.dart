import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../exercises/data/exercise_repository.dart';
import 'history_csv.dart';

/// What an import will do, shown to the user before they confirm.
class ImportPreview {
  ImportPreview({
    required this.parsed,
    required this.toImport,
    required this.alreadyImported,
    required this.newExercises,
    required this.unknownExercises,
  });

  final ParsedHistory parsed;

  /// Workouts that will be written.
  final List<ImportWorkout> toImport;

  /// Workouts skipped because a completed workout with the same name
  /// already exists on that day (so importing twice is harmless).
  final List<ImportWorkout> alreadyImported;

  /// Custom exercises that will be created, with their details.
  final List<ImportExercise> newExercises;

  /// Exercises not in the library and without muscle/equipment details.
  /// The import is blocked until these are fixed in the logger.
  final List<String> unknownExercises;

  int get setCount => toImport.fold(0, (n, w) => n + w.setCount);
  bool get canImport => toImport.isNotEmpty && unknownExercises.isEmpty;
}

class ImportResult {
  const ImportResult(this.workouts, this.sets, this.exercisesCreated);
  final int workouts;
  final int sets;
  final int exercisesCreated;
}

/// Past workouts have no clock time, so they're placed at midday local
/// time: it can't slip to a neighbouring date in any time zone shift.
DateTime importStartTime(DateTime date) =>
    DateTime(date.year, date.month, date.day, 12);

class HistoryImporter {
  HistoryImporter(this._db);
  final AppDatabase _db;

  Future<ImportPreview> preview(ParsedHistory parsed) async {
    final library = await _libraryByName();
    final toImport = <ImportWorkout>[];
    final already = <ImportWorkout>[];
    final newByName = <String, ImportExercise>{};
    final unknown = <String>{};

    for (final w in parsed.workouts) {
      if (await _exists(w)) {
        already.add(w);
        continue;
      }
      toImport.add(w);
      for (final e in w.exercises) {
        final key = e.name.toLowerCase();
        if (library.containsKey(key)) continue;
        if (e.spec == null) {
          unknown.add(e.name);
        } else {
          newByName.putIfAbsent(key, () => e);
        }
      }
    }
    return ImportPreview(
      parsed: parsed,
      toImport: toImport,
      alreadyImported: already,
      newExercises: newByName.values.toList(),
      unknownExercises: unknown.toList(),
    );
  }

  /// Writes every workout in [preview] in one transaction: all or nothing.
  Future<ImportResult> run(ImportPreview preview) {
    if (!preview.canImport) {
      throw StateError('Fix the problems shown before importing.');
    }
    return _db.transaction(() async {
      final library = await _libraryByName();
      var created = 0;

      for (final e in preview.newExercises) {
        final spec = e.spec!;
        final id = await _db
            .into(_db.exercises)
            .insert(
              ExercisesCompanion.insert(
                name: normalizeExerciseName(e.name),
                primaryMuscle: spec.muscle,
                equipment: spec.equipment,
                trackingType: spec.tracking,
                isCustom: const Value(true),
              ),
            );
        library[e.name.toLowerCase()] = await (_db.select(
          _db.exercises,
        )..where((x) => x.id.equals(id))).getSingle();
        created++;
      }

      var sets = 0;
      for (final w in preview.toImport) {
        final start = importStartTime(w.date);
        final durationSeconds = w.durationMin == null
            ? null
            : w.durationMin! * 60;
        final end = start.add(Duration(seconds: durationSeconds ?? 0));
        final workoutId = await _db
            .into(_db.workouts)
            .insert(
              WorkoutsCompanion.insert(
                name: w.name,
                status: WorkoutStatus.completed,
                startedAt: start,
                completedAt: Value(end),
                durationSeconds: Value(durationSeconds),
                notes: const Value('Imported from history'),
              ),
            );

        for (var p = 0; p < w.exercises.length; p++) {
          final e = w.exercises[p];
          final exercise = library[e.name.toLowerCase()]!;
          final weId = await _db
              .into(_db.workoutExercises)
              .insert(
                WorkoutExercisesCompanion.insert(
                  workoutId: workoutId,
                  exerciseId: exercise.id,
                  exerciseNameSnapshot: exercise.name,
                  position: p,
                ),
              );
          final assisted =
              exercise.trackingType == TrackingType.assistedBodyweight;
          final timed = exercise.trackingType == TrackingType.duration;
          for (var s = 0; s < e.rawSets.length; s++) {
            final set = e.rawSets[s];
            final kg = set.weightKg;
            await _db
                .into(_db.workoutSets)
                .insert(
                  WorkoutSetsCompanion.insert(
                    workoutExerciseId: weId,
                    setNumber: s + 1,
                    setType: set.type,
                    weightKg: Value(
                      kg == null || timed ? null : (assisted ? -kg : kg),
                    ),
                    reps: Value(timed ? null : set.reps),
                    durationSeconds: Value(set.seconds),
                    bandLevel: Value(set.band),
                    isCompleted: const Value(true),
                    completedAt: Value(end),
                  ),
                );
            sets++;
          }
        }
      }
      return ImportResult(preview.toImport.length, sets, created);
    });
  }

  /// Every exercise by lower-case name; active ones win over archived.
  Future<Map<String, Exercise>> _libraryByName() async {
    final all = await _db.select(_db.exercises).get();
    final map = <String, Exercise>{};
    for (final e in all.where((e) => e.archivedAt != null)) {
      map[e.name.toLowerCase()] = e;
    }
    for (final e in all.where((e) => e.archivedAt == null)) {
      map[e.name.toLowerCase()] = e;
    }
    return map;
  }

  Future<bool> _exists(ImportWorkout w) async {
    final dayStart = DateTime(w.date.year, w.date.month, w.date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final found =
        await (_db.select(_db.workouts)
              ..where(
                (x) =>
                    x.status.equalsValue(WorkoutStatus.completed) &
                    x.name.lower().equals(w.name.toLowerCase()) &
                    x.startedAt.isBiggerOrEqualValue(dayStart) &
                    x.startedAt.isSmallerThanValue(dayEnd),
              )
              ..limit(1))
            .get();
    return found.isNotEmpty;
  }
}

final historyImporterProvider = Provider<HistoryImporter>(
  (ref) => HistoryImporter(ref.watch(databaseProvider)),
);
