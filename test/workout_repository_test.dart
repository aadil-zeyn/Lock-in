import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/workout/data/workout_repository.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutRepository(db);
  });
  tearDown(() => db.close());

  Future<Exercise> ex(String name) =>
      (db.select(db.exercises)..where((e) => e.name.equals(name))).getSingle();

  Future<WorkoutDetail> detail(int id) async => (await repo.loadDetail(id))!;

  /// Logs one finished workout of [sets] (weight, reps) for [name].
  Future<int> logPast(String name, List<(double, int)> sets) async {
    final w = await repo.start(now: DateTime(2026, 11, 1, 18));
    final we = await repo.addExercise(w, await ex(name));
    var d = await detail(w);
    final first = d.exercises.single.sets.single;
    await repo.updateSet(
      first.id,
      weightKg: Value(sets.first.$1),
      reps: Value(sets.first.$2),
    );
    await repo.setCompleted(first.id, true);
    for (final s in sets.skip(1)) {
      final id = await repo.addSet(we);
      await repo.updateSet(id, weightKg: Value(s.$1), reps: Value(s.$2));
      await repo.setCompleted(id, true);
    }
    d = await detail(w);
    await repo.finish(w, now: DateTime(2026, 11, 1, 19));
    return w;
  }

  test('only one workout can be active', () async {
    final a = await repo.start();
    final b = await repo.start(name: 'Another');
    expect(b, a);
    expect(
      await (db.select(
        db.workouts,
      )..where((w) => w.status.equalsValue(WorkoutStatus.active))).get(),
      hasLength(1),
    );
  });

  test('default name follows the time of day', () {
    expect(defaultWorkoutName(DateTime(2026, 1, 1, 7)), 'Morning workout');
    expect(defaultWorkoutName(DateTime(2026, 1, 1, 14)), 'Afternoon workout');
    expect(defaultWorkoutName(DateTime(2026, 1, 1, 20)), 'Evening workout');
  });

  test('new sets copy the previous set; first set copies last time', () async {
    await logPast('Barbell Bench Press', [(60, 8), (60, 7)]);

    final w = await repo.start();
    final we = await repo.addExercise(w, await ex('Barbell Bench Press'));
    var sets = (await detail(w)).exercises.single.sets;
    expect(sets.single.weightKg, 60);
    expect(sets.single.reps, 8);
    expect(sets.single.isCompleted, isFalse);

    await repo.updateSet(sets.single.id, weightKg: const Value(62.5));
    await repo.addSet(we);
    sets = (await detail(w)).exercises.single.sets;
    expect(sets.map((s) => s.setNumber), [1, 2]);
    expect(sets.last.weightKg, 62.5);
  });

  test('last performance skips the current workout', () async {
    await logPast('Deadlift', [(140, 5), (150, 3)]);
    final w = await repo.start();
    await repo.addExercise(w, await ex('Deadlift'));
    final prev = await repo.lastPerformance(
      (await ex('Deadlift')).id,
      excludeWorkoutId: w,
    );
    expect(prev.map((p) => (p.weightKg, p.reps)), [(140.0, 5), (150.0, 3)]);
  });

  test('deleting a set renumbers the rest', () async {
    final w = await repo.start();
    final we = await repo.addExercise(w, await ex('Barbell Row'));
    await repo.addSet(we);
    await repo.addSet(we);
    var sets = (await detail(w)).exercises.single.sets;
    await repo.deleteSet(sets[1].id);
    sets = (await detail(w)).exercises.single.sets;
    expect(sets.map((s) => s.setNumber), [1, 2]);
  });

  test('exercises can be moved and removed', () async {
    final w = await repo.start();
    final a = await repo.addExercise(w, await ex('Back Squat'));
    await repo.addExercise(w, await ex('Leg Press'));
    await repo.addExercise(w, await ex('Leg Extension'));
    await repo.moveExercise(a, 1);
    var names = (await detail(w)).exercises.map((e) => e.name);
    expect(names, ['Leg Press', 'Back Squat', 'Leg Extension']);
    await repo.removeExercise(a);
    names = (await detail(w)).exercises.map((e) => e.name);
    expect(names, ['Leg Press', 'Leg Extension']);
    expect((await detail(w)).exercises.map((e) => e.entry.position), [0, 1]);
  });

  test(
    'finish keeps entered sets, drops empty ones, records duration',
    () async {
      final w = await repo.start(now: DateTime(2026, 11, 6, 18));
      final squat = await repo.addExercise(w, await ex('Back Squat'));
      await repo.addExercise(w, await ex('Plank')); // left empty
      final s1 = (await detail(w)).exercises.first.sets.single;
      await repo.updateSet(
        s1.id,
        weightKg: const Value(100),
        reps: const Value(5),
      );
      await repo.setCompleted(s1.id, true);
      final warm = await repo.addSet(squat);
      await repo.updateSet(
        warm,
        weightKg: const Value(60),
        reps: const Value(10),
        type: const Value(SetType.warmup),
      );
      await repo.setCompleted(warm, true);

      final summary = await repo.finish(w, now: DateTime(2026, 11, 6, 19, 5));
      expect(summary.duration, const Duration(minutes: 65));
      expect(summary.exercises, 1, reason: 'empty Plank removed');
      expect(summary.sets, 2);
      expect(summary.volumeKg, 500, reason: 'warm-up excluded');

      final saved = (await detail(w)).workout;
      expect(saved.status, WorkoutStatus.completed);
      expect(saved.durationSeconds, 65 * 60);
      expect(await repo.active(), isNull);
    },
  );

  test('discard removes only the active workout', () async {
    final done = await logPast('Pull-up', [(0, 10)]);
    final w = await repo.start();
    await repo.addExercise(w, await ex('Pull-up'));
    await repo.discard(w);
    await repo.discard(done); // completed workouts are never discarded
    final left = await db.select(db.workouts).get();
    expect(left.map((x) => x.id), [done]);
  });

  test('band sets store the band level', () async {
    final w = await repo.start();
    await repo.addExercise(w, await ex('Band Face Pull'));
    final set = (await detail(w)).exercises.single.sets.single;
    await repo.updateSet(
      set.id,
      band: const Value(BandLevel.heavy),
      reps: const Value(15),
    );
    final saved = (await detail(w)).exercises.single.sets.single;
    expect(saved.bandLevel, BandLevel.heavy);
    expect(saved.reps, 15);
  });
}
