import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/strength.dart';

/// One exercise inside a workout, with its sets in order.
class WorkoutExerciseDetail {
  const WorkoutExerciseDetail({
    required this.entry,
    required this.exercise,
    required this.sets,
  });
  final WorkoutExercise entry;
  final Exercise exercise;
  final List<WorkoutSet> sets;

  /// Name as logged (survives renames).
  String get name => entry.exerciseNameSnapshot;
}

class WorkoutDetail {
  const WorkoutDetail(this.workout, this.exercises);
  final Workout workout;
  final List<WorkoutExerciseDetail> exercises;

  int get totalSets => exercises.fold(0, (n, e) => n + e.sets.length);
  int get completedSets => exercises.fold(
    0,
    (n, e) => n + e.sets.where((s) => s.isCompleted).length,
  );

  /// kg; completed working sets of weight × reps exercises only.
  double get volumeKg {
    var v = 0.0;
    for (final e in exercises) {
      if (e.exercise.trackingType != TrackingType.weightReps) continue;
      for (final s in e.sets) {
        if (s.isCompleted && s.setType.countsTowardStats) {
          v += setVolume(s.weightKg, s.reps);
        }
      }
    }
    return v;
  }
}

/// What a set was last time, for the inline "Last: 60 × 8" hint.
typedef PreviousSet = ({
  double? weightKg,
  int? reps,
  int? seconds,
  BandLevel? band,
});

class FinishSummary {
  const FinishSummary({
    required this.workoutId,
    required this.duration,
    required this.sets,
    required this.exercises,
    required this.volumeKg,
  });
  final int workoutId;
  final Duration duration;
  final int sets;
  final int exercises;
  final double volumeKg;
}

String defaultWorkoutName(DateTime now) {
  if (now.hour < 12) return 'Morning workout';
  if (now.hour < 17) return 'Afternoon workout';
  return 'Evening workout';
}

class WorkoutRepository {
  WorkoutRepository(this._db);
  final AppDatabase _db;

  Future<Workout?> active() =>
      (_db.select(_db.workouts)
            ..where((w) => w.status.equalsValue(WorkoutStatus.active))
            ..limit(1))
          .getSingleOrNull();

  /// Starts a workout, or returns the one already in progress — there is
  /// only ever one (enforced by a partial unique index).
  Future<int> start({String? name, DateTime? now}) async {
    final existing = await active();
    if (existing != null) return existing.id;
    final at = now ?? DateTime.now();
    return _db
        .into(_db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            name: (name == null || name.trim().isEmpty)
                ? defaultWorkoutName(at)
                : name.trim(),
            status: WorkoutStatus.active,
            startedAt: at,
          ),
        );
  }

  Future<void> rename(int workoutId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await (_db.update(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(
        name: Value(clean.length > 60 ? clean.substring(0, 60) : clean),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Adds an exercise at the end with one set pre-filled from last time.
  Future<int> addExercise(int workoutId, Exercise exercise) {
    return _db.transaction(() async {
      final last =
          await (_db.select(_db.workoutExercises)
                ..where((x) => x.workoutId.equals(workoutId))
                ..orderBy([(x) => OrderingTerm.desc(x.position)])
                ..limit(1))
              .getSingleOrNull();
      final id = await _db
          .into(_db.workoutExercises)
          .insert(
            WorkoutExercisesCompanion.insert(
              workoutId: workoutId,
              exerciseId: exercise.id,
              exerciseNameSnapshot: exercise.name,
              position: (last?.position ?? -1) + 1,
            ),
          );
      await addSet(id);
      return id;
    });
  }

  /// New set: copies the previous set in this workout, otherwise the same
  /// set number from last time, otherwise empty.
  Future<int> addSet(int workoutExerciseId) async {
    final entry = await (_db.select(
      _db.workoutExercises,
    )..where((x) => x.id.equals(workoutExerciseId))).getSingle();
    final sets = await _setsOf(workoutExerciseId);
    final number = sets.length + 1;

    double? weight;
    int? reps;
    int? seconds;
    BandLevel? band;
    var type = SetType.normal;
    if (sets.isNotEmpty) {
      final p = sets.last;
      weight = p.weightKg;
      reps = p.reps;
      seconds = p.durationSeconds;
      band = p.bandLevel;
      type = p.setType == SetType.warmup ? SetType.normal : p.setType;
    } else {
      final prev = await lastPerformance(
        entry.exerciseId,
        excludeWorkoutId: entry.workoutId,
      );
      if (prev.isNotEmpty) {
        final p = prev.first;
        weight = p.weightKg;
        reps = p.reps;
        seconds = p.seconds;
        band = p.band;
      }
    }
    return _db
        .into(_db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: workoutExerciseId,
            setNumber: number,
            setType: type,
            weightKg: Value(weight),
            reps: Value(reps),
            durationSeconds: Value(seconds),
            bandLevel: Value(band),
          ),
        );
  }

  /// Saves one field change immediately. Pass `Value(null)` to clear.
  Future<void> updateSet(
    int setId, {
    Value<double?> weightKg = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> seconds = const Value.absent(),
    Value<BandLevel?> band = const Value.absent(),
    Value<SetType> type = const Value.absent(),
  }) async {
    await (_db.update(_db.workoutSets)..where((s) => s.id.equals(setId))).write(
      WorkoutSetsCompanion(
        weightKg: weightKg,
        reps: reps,
        durationSeconds: seconds,
        bandLevel: band,
        setType: type,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setCompleted(int setId, bool done) async {
    await (_db.update(_db.workoutSets)..where((s) => s.id.equals(setId))).write(
      WorkoutSetsCompanion(
        isCompleted: Value(done),
        completedAt: Value(done ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes a set and renumbers the rest so there are no gaps.
  Future<void> deleteSet(int setId) {
    return _db.transaction(() async {
      final set = await (_db.select(
        _db.workoutSets,
      )..where((s) => s.id.equals(setId))).getSingleOrNull();
      if (set == null) return;
      await (_db.delete(
        _db.workoutSets,
      )..where((s) => s.id.equals(setId))).go();
      await _renumber(set.workoutExerciseId);
    });
  }

  Future<void> removeExercise(int workoutExerciseId) {
    return _db.transaction(() async {
      final entry = await (_db.select(
        _db.workoutExercises,
      )..where((x) => x.id.equals(workoutExerciseId))).getSingleOrNull();
      if (entry == null) return;
      await (_db.delete(
        _db.workoutExercises,
      )..where((x) => x.id.equals(workoutExerciseId))).go();
      await _reposition(entry.workoutId);
    });
  }

  /// Moves an exercise one place up (-1) or down (+1).
  Future<void> moveExercise(int workoutExerciseId, int delta) {
    return _db.transaction(() async {
      final entry = await (_db.select(
        _db.workoutExercises,
      )..where((x) => x.id.equals(workoutExerciseId))).getSingle();
      final all = await _entriesOf(entry.workoutId);
      final i = all.indexWhere((x) => x.id == workoutExerciseId);
      final j = i + delta;
      if (i < 0 || j < 0 || j >= all.length) return;
      // Swap with the neighbour (positions are kept contiguous 0..n-1).
      Future<void> place(int id, int position) =>
          (_db.update(_db.workoutExercises)..where((x) => x.id.equals(id)))
              .write(WorkoutExercisesCompanion(position: Value(position)));
      await place(all[i].id, j);
      await place(all[j].id, i);
    });
  }

  /// Drops sets with nothing entered and exercises left without sets,
  /// keeping numbering and order contiguous. Status is unchanged.
  Future<void> _tidy(int workoutId) async {
    for (final entry in await _entriesOf(workoutId)) {
      for (final s in await _setsOf(entry.id)) {
        final empty =
            (s.reps ?? 0) <= 0 &&
            (s.durationSeconds ?? 0) <= 0 &&
            !s.isCompleted;
        if (empty) {
          await (_db.delete(
            _db.workoutSets,
          )..where((x) => x.id.equals(s.id))).go();
        }
      }
      await _renumber(entry.id);
      if ((await _setsOf(entry.id)).isEmpty) {
        await (_db.delete(
          _db.workoutExercises,
        )..where((x) => x.id.equals(entry.id))).go();
      }
    }
    await _reposition(workoutId);
  }

  /// Finishes editing a past workout: tidies empty rows, keeps it completed.
  Future<void> saveEdits(int workoutId) => _db.transaction(() async {
    await _tidy(workoutId);
    await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId)))
        .write(WorkoutsCompanion(updatedAt: Value(DateTime.now())));
  });

  /// Corrects when a past workout happened and how long it took.
  Future<void> setTiming(
    int workoutId, {
    required DateTime startedAt,
    required Duration duration,
  }) async {
    await (_db.update(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(
        startedAt: Value(startedAt),
        durationSeconds: Value(duration.inSeconds),
        completedAt: Value(startedAt.add(duration)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Completes the workout. Sets with nothing entered and exercises left
  /// with no sets are dropped; everything typed in is kept.
  Future<FinishSummary> finish(int workoutId, {DateTime? now}) {
    return _db.transaction(() async {
      final workout = await (_db.select(
        _db.workouts,
      )..where((w) => w.id.equals(workoutId))).getSingle();
      final end = now ?? DateTime.now();

      await _tidy(workoutId);

      final duration = end.difference(workout.startedAt);
      await (_db.update(
        _db.workouts,
      )..where((w) => w.id.equals(workoutId))).write(
        WorkoutsCompanion(
          status: const Value(WorkoutStatus.completed),
          completedAt: Value(end),
          durationSeconds: Value(duration.inSeconds),
          updatedAt: Value(end),
        ),
      );

      final detail = await loadDetail(workoutId);
      return FinishSummary(
        workoutId: workoutId,
        duration: duration,
        sets: detail?.completedSets ?? 0,
        exercises: detail?.exercises.length ?? 0,
        volumeKg: detail?.volumeKg ?? 0,
      );
    });
  }

  /// Throws the session away. Its rows are deleted: a discarded workout
  /// never counts anywhere, so there is nothing worth keeping.
  Future<void> discard(int workoutId) async {
    await (_db.delete(_db.workouts)..where(
          (w) =>
              w.id.equals(workoutId) &
              w.status.equalsValue(WorkoutStatus.active),
        ))
        .go();
  }

  /// Deletes a finished workout from history (the user confirms first).
  /// Its exercises and sets go with it (cascade); exercises stay in the
  /// library.
  Future<void> deleteCompleted(int workoutId) async {
    await (_db.delete(_db.workouts)..where(
          (w) =>
              w.id.equals(workoutId) &
              w.status.equalsValue(WorkoutStatus.completed),
        ))
        .go();
  }

  /// Sets from the most recent completed workout with this exercise.
  Future<List<PreviousSet>> lastPerformance(
    int exerciseId, {
    int? excludeWorkoutId,
  }) async {
    final query =
        _db.select(_db.workoutExercises).join([
            innerJoin(
              _db.workouts,
              _db.workouts.id.equalsExp(_db.workoutExercises.workoutId),
            ),
          ])
          ..where(
            _db.workoutExercises.exerciseId.equals(exerciseId) &
                _db.workouts.status.equalsValue(WorkoutStatus.completed),
          )
          ..orderBy([OrderingTerm.desc(_db.workouts.startedAt)])
          ..limit(1);
    if (excludeWorkoutId != null) {
      query.where(_db.workouts.id.equals(excludeWorkoutId).not());
    }
    final row = await query.getSingleOrNull();
    if (row == null) return const [];
    final entry = row.readTable(_db.workoutExercises);
    final sets = await _setsOf(entry.id);
    return [
      for (final s in sets.where((s) => s.isCompleted))
        (
          weightKg: s.weightKg,
          reps: s.reps,
          seconds: s.durationSeconds,
          band: s.bandLevel,
        ),
    ];
  }

  Future<WorkoutDetail?> loadDetail(int workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return null;
    final rows =
        await (_db.select(_db.workoutExercises).join([
                innerJoin(
                  _db.exercises,
                  _db.exercises.id.equalsExp(_db.workoutExercises.exerciseId),
                ),
              ])
              ..where(_db.workoutExercises.workoutId.equals(workoutId))
              ..orderBy([OrderingTerm.asc(_db.workoutExercises.position)]))
            .get();
    final entryIds = rows.map((r) => r.readTable(_db.workoutExercises).id);
    final allSets =
        await (_db.select(_db.workoutSets)
              ..where((s) => s.workoutExerciseId.isIn(entryIds))
              ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
            .get();
    return WorkoutDetail(workout, [
      for (final r in rows)
        WorkoutExerciseDetail(
          entry: r.readTable(_db.workoutExercises),
          exercise: r.readTable(_db.exercises),
          sets: allSets
              .where(
                (s) =>
                    s.workoutExerciseId == r.readTable(_db.workoutExercises).id,
              )
              .toList(),
        ),
    ]);
  }

  /// Re-emits whenever the workout, its exercises or its sets change.
  Stream<WorkoutDetail?> watchDetail(int workoutId) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.workouts,
            _db.workoutExercises,
            _db.workoutSets,
            _db.exercises,
          },
        )
        .watch()
        .asyncMap((_) => loadDetail(workoutId));
  }

  Future<List<WorkoutExercise>> _entriesOf(int workoutId) =>
      (_db.select(_db.workoutExercises)
            ..where((x) => x.workoutId.equals(workoutId))
            ..orderBy([(x) => OrderingTerm.asc(x.position)]))
          .get();

  Future<List<WorkoutSet>> _setsOf(int workoutExerciseId) =>
      (_db.select(_db.workoutSets)
            ..where((s) => s.workoutExerciseId.equals(workoutExerciseId))
            ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
          .get();

  Future<void> _renumber(int workoutExerciseId) async {
    final sets = await _setsOf(workoutExerciseId);
    for (var i = 0; i < sets.length; i++) {
      if (sets[i].setNumber != i + 1) {
        await (_db.update(_db.workoutSets)
              ..where((s) => s.id.equals(sets[i].id)))
            .write(WorkoutSetsCompanion(setNumber: Value(i + 1)));
      }
    }
  }

  Future<void> _reposition(int workoutId) async {
    final all = await _entriesOf(workoutId);
    for (var i = 0; i < all.length; i++) {
      if (all[i].position != i) {
        await (_db.update(_db.workoutExercises)
              ..where((x) => x.id.equals(all[i].id)))
            .write(WorkoutExercisesCompanion(position: Value(i)));
      }
    }
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(databaseProvider)),
);

final workoutDetailProvider = StreamProvider.autoDispose
    .family<WorkoutDetail?, int>(
      (ref, id) => ref.watch(workoutRepositoryProvider).watchDetail(id),
    );

final lastPerformanceProvider = FutureProvider.autoDispose
    .family<List<PreviousSet>, ({int exerciseId, int workoutId})>(
      (ref, key) => ref
          .watch(workoutRepositoryProvider)
          .lastPerformance(key.exerciseId, excludeWorkoutId: key.workoutId),
    );
