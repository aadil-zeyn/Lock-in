import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'enums.dart';
import 'seed_exercises.dart';

export 'enums.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
//
// Units: weights are always stored in kg, lengths in cm, body fat in %.
// The user's unit preference only changes display and input.
// ---------------------------------------------------------------------------

/// Single-row table (id = 1).
class UserProfiles extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get weightUnit => textEnum<WeightUnit>()();
  TextColumn get lengthUnit => textEnum<LengthUnit>()();
  IntColumn get restTimerSeconds => integer().withDefault(const Constant(90))();

  // Weekly goals that drive the Home activity rings.
  IntColumn get weeklyWorkoutGoal => integer().withDefault(const Constant(3))();
  IntColumn get weeklyMinutesGoal =>
      integer().withDefault(const Constant(180))();
  IntColumn get weeklySetsGoal => integer().withDefault(const Constant(45))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_exercises_name', columns: {#name})
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get primaryMuscle => textEnum<MuscleGroup>()();

  /// Comma-separated [MuscleGroup] names, e.g. "triceps,shoulders".
  TextColumn get secondaryMuscles => text().withDefault(const Constant(''))();
  TextColumn get equipment => textEnum<Equipment>()();
  TextColumn get trackingType => textEnum<TrackingType>()();
  TextColumn get description => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  /// Exercises are archived, never hard-deleted, so history stays intact.
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_routine_exercises_routine', columns: {#routineId})
class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get position => integer()();
  IntColumn get suggestedSets => integer().withDefault(const Constant(3))();
}

@TableIndex(name: 'idx_workouts_status', columns: {#status})
@TableIndex(name: 'idx_workouts_started_at', columns: {#startedAt})
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get status => textEnum<WorkoutStatus>()();

  /// Which routine this was started from, if any. The workout never
  /// depends on the routine's current contents.
  IntColumn get routineId => integer().nullable().references(
    Routines,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_workout_exercises_workout', columns: {#workoutId})
@TableIndex(name: 'idx_workout_exercises_exercise', columns: {#exerciseId})
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();

  /// Name at the time it was logged — history survives renames.
  TextColumn get exerciseNameSnapshot => text()();
  IntColumn get position => integer()();
  TextColumn get notes => text().nullable()();
}

@TableIndex(name: 'idx_workout_sets_we', columns: {#workoutExerciseId})
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId => integer().references(
    WorkoutExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get setNumber => integer()();
  TextColumn get setType => textEnum<SetType>()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  /// Band used, for `TrackingType.bandReps` exercises (schema v2).
  TextColumn get bandLevel => textEnum<BandLevel>().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(
  name: 'idx_body_measurements_type_date',
  columns: {#measurementType, #recordedAt},
)
class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get measurementType => textEnum<MeasurementType>()();

  /// kg for body weight, % for body fat, cm for everything else.
  RealColumn get measuredValue => real()();
  DateTimeColumn get recordedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    UserProfiles,
    Exercises,
    Routines,
    RoutineExercises,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
    BodyMeasurements,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'lock_in',
              // Browser build: SQLite runs as WebAssembly and stores data in
              // the browser (OPFS or IndexedDB). The files live in `web/` and
              // must match the sqlite3 / drift package versions.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  /// v1: initial schema. v2: band level on sets + band exercises.
  /// The app is installed on a real phone now: every schema change needs
  /// a step in `onUpgrade` and a test in `test/migration_test.dart`.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // At most one active workout at any time.
      await customStatement(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_one_active_workout "
        "ON workouts(status) WHERE status = 'active'",
      );

      await batch((b) {
        b.insert(
          userProfiles,
          UserProfilesCompanion.insert(
            id: const Value(1),
            weightUnit: WeightUnit.kg,
            lengthUnit: LengthUnit.cm,
          ),
        );
        b.insertAll(exercises, seedExercises());
      });
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(workoutSets, workoutSets.bandLevel);
        await _insertMissing(bandSeedExercises());
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Adds seed exercises whose name isn't in the library yet, so an
  /// upgrade never duplicates something the user already created.
  Future<void> _insertMissing(List<ExercisesCompanion> seeds) async {
    final existing = (await select(
      exercises,
    ).get()).map((e) => e.name.toLowerCase()).toSet();
    final fresh = seeds
        .where((s) => !existing.contains(s.name.value.toLowerCase()))
        .toList();
    if (fresh.isEmpty) return;
    await batch((b) => b.insertAll(exercises, fresh));
  }
}
