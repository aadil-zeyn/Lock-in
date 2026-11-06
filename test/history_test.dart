import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/core/database/database_provider.dart';
import 'package:lock_in/features/history/data/history_providers.dart';
import 'package:lock_in/features/workout/data/workout_repository.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;
  late WorkoutRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    repo = WorkoutRepository(db);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<int> finished(String name, DateTime at, int ticked) async {
    final w = await repo.start(name: name, now: at);
    final ex = await (db.select(db.exercises)..limit(1)).getSingle();
    final we = await repo.addExercise(w, ex);
    for (var i = 1; i < ticked; i++) {
      await repo.addSet(we);
    }
    final sets = (await repo.loadDetail(w))!.exercises.single.sets;
    for (final s in sets) {
      await repo.updateSet(s.id, reps: const Value(8));
      await repo.setCompleted(s.id, true);
    }
    await repo.finish(w, now: at.add(const Duration(minutes: 50)));
    return w;
  }

  test('history lists completed workouts newest first with counts', () async {
    await finished('Push', DateTime(2026, 11, 2, 18), 3);
    await finished('Pull', DateTime(2026, 11, 4, 18), 2);
    await repo.start(name: 'In progress'); // active: not in history

    // Listen like a screen does (Riverpod pauses unlistened providers).
    final sub = c.listen(workoutHistoryProvider, (_, _) {});
    addTearDown(sub.close);
    final items = await c.read(workoutHistoryProvider.future);
    expect(items.map((i) => i.workout.name), ['Pull', 'Push']);
    expect(items.last.sets, 3);
    expect(items.last.exercises, 1);
  });

  test(
    'deleteCompleted removes a finished workout, not an active one',
    () async {
      final done = await finished('Legs', DateTime(2026, 11, 3, 18), 1);
      final active = await repo.start(name: 'Now');
      await repo.deleteCompleted(active);
      await repo.deleteCompleted(done);
      final left = await db.select(db.workouts).get();
      expect(left.map((w) => w.id), [active]);
      expect(
        await db.select(db.workoutSets).get(),
        isEmpty,
        reason: 'sets of the deleted workout go too',
      );
    },
  );
}
