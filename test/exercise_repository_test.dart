import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/core/database/seed_exercises.dart';
import 'package:lock_in/features/exercises/data/exercise_repository.dart';

ExerciseDraft draft(
  String name, {
  MuscleGroup primary = MuscleGroup.chest,
  Set<MuscleGroup> secondary = const {},
  Equipment equipment = Equipment.cable,
  TrackingType tracking = TrackingType.weightReps,
  String? description,
}) => ExerciseDraft(
  name: name,
  primaryMuscle: primary,
  secondaryMuscles: secondary,
  equipment: equipment,
  trackingType: tracking,
  description: description,
);

void main() {
  late AppDatabase db;
  late ExerciseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ExerciseRepository(db);
  });
  tearDown(() => db.close());

  Future<Exercise> byId(int id) =>
      (db.select(db.exercises)..where((e) => e.id.equals(id))).getSingle();

  group('name validation', () {
    test('trims and collapses whitespace', () {
      expect(normalizeExerciseName('  Cable   Fly '), 'Cable Fly');
    });
    test('rejects blank and over-long names', () {
      expect(validateExerciseName('   '), isNotNull);
      expect(validateExerciseName('a' * 81), isNotNull);
      expect(validateExerciseName('Landmine Press'), isNull);
    });
  });

  group('muscle encoding', () {
    test('round-trips and uses a stable order', () {
      final csv = encodeMuscles({MuscleGroup.triceps, MuscleGroup.chest});
      expect(csv, 'chest,triceps');
      expect(decodeMuscles(csv), [MuscleGroup.chest, MuscleGroup.triceps]);
    });
    test('ignores empty and unknown values', () {
      expect(decodeMuscles(''), isEmpty);
      expect(decodeMuscles('chest,nope'), [MuscleGroup.chest]);
    });
  });

  group('create', () {
    test('saves a custom exercise with cleaned fields', () async {
      final id = await repo.create(
        draft(
          '  Landmine   Press ',
          primary: MuscleGroup.shoulders,
          // Primary listed as secondary too — must be dropped.
          secondary: {MuscleGroup.shoulders, MuscleGroup.triceps},
          description: '   ',
        ),
      );
      final e = await byId(id);
      expect(e.name, 'Landmine Press');
      expect(e.isCustom, isTrue);
      expect(e.secondaryMuscleList, [MuscleGroup.triceps]);
      expect(e.description, isNull);
      expect(e.archivedAt, isNull);
    });

    test('rejects a name already in the library, ignoring case', () async {
      // "Barbell Bench Press" is in the seed list.
      expect(
        () => repo.create(draft('barbell  bench press')),
        throwsA(isA<DuplicateExerciseNameException>()),
      );
    });

    test('allows reusing the name of an archived exercise', () async {
      final id = await repo.create(draft('Cable Press'));
      await repo.archive(id);
      expect(await repo.create(draft('Cable Press')), isNot(id));
    });

    test('rejects an empty name', () {
      expect(() => repo.create(draft('  ')), throwsArgumentError);
    });
  });

  group('update', () {
    test('edits a custom exercise', () async {
      final id = await repo.create(draft('Cable Press'));
      await repo.update(
        id,
        draft(
          'Cable Chest Press',
          equipment: Equipment.machine,
          description: 'Seat 4',
        ),
      );
      final e = await byId(id);
      expect(e.name, 'Cable Chest Press');
      expect(e.equipment, Equipment.machine);
      expect(e.description, 'Seat 4');
    });

    test('keeping its own name is not a duplicate', () async {
      final id = await repo.create(draft('Cable Press'));
      await repo.update(id, draft('cable press'));
      expect((await byId(id)).name, 'cable press');
    });

    test('refuses to edit built-in exercises', () async {
      final builtIn =
          await (db.select(db.exercises)
                ..where((e) => e.isCustom.equals(false))
                ..limit(1))
              .getSingle();
      expect(
        () => repo.update(builtIn.id, draft('Renamed')),
        throwsA(isA<BuiltInExerciseException>()),
      );
    });

    test('rejects renaming onto another exercise', () async {
      final id = await repo.create(draft('Cable Press'));
      expect(
        () => repo.update(id, draft('Deadlift')),
        throwsA(isA<DuplicateExerciseNameException>()),
      );
    });
  });

  group('archive / restore', () {
    test('archiving hides the exercise but keeps the row', () async {
      final id = await repo.create(draft('Cable Press'));
      await repo.archive(id);
      final e = await byId(id);
      expect(e.archivedAt, isNotNull);
      expect(await repo.isNameTaken('Cable Press'), isFalse);
    });

    test('built-in exercises can be archived and restored', () async {
      final builtIn = await (db.select(db.exercises)..limit(1)).getSingle();
      await repo.archive(builtIn.id);
      await repo.restore(builtIn.id);
      expect((await byId(builtIn.id)).archivedAt, isNull);
    });

    test('restore fails if the name was taken meanwhile', () async {
      final first = await repo.create(draft('Cable Press'));
      await repo.archive(first);
      await repo.create(draft('Cable Press'));
      expect(
        () => repo.restore(first),
        throwsA(isA<DuplicateExerciseNameException>()),
      );
    });

    test(
      'a logged exercise cannot be hard-deleted (history is safe)',
      () async {
        final id = await repo.create(draft('Cable Press'));
        final workoutId = await db
            .into(db.workouts)
            .insert(
              WorkoutsCompanion.insert(
                name: 'Push',
                status: WorkoutStatus.completed,
                startedAt: DateTime(2026, 11, 2),
              ),
            );
        await db
            .into(db.workoutExercises)
            .insert(
              WorkoutExercisesCompanion.insert(
                workoutId: workoutId,
                exerciseId: id,
                exerciseNameSnapshot: 'Cable Press',
                position: 0,
              ),
            );
        expect(
          () => (db.delete(db.exercises)..where((e) => e.id.equals(id))).go(),
          throwsA(isA<SqliteException>()),
        );
        // Renaming doesn't touch the logged name.
        await repo.update(id, draft('Cable Chest Press'));
        final logged = await db.select(db.workoutExercises).getSingle();
        expect(logged.exerciseNameSnapshot, 'Cable Press');
      },
    );
  });

  test('seed library is fully inserted with unique names', () async {
    final all = await db.select(db.exercises).get();
    expect(all, hasLength(seedExercises().length));
    expect(all.map((e) => e.name.toLowerCase()).toSet(), hasLength(all.length));
  });
}
