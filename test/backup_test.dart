import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/body/data/body_repository.dart';
import 'package:lock_in/features/exercises/data/exercise_repository.dart';
import 'package:lock_in/features/food/data/food_repository.dart';
import 'package:lock_in/features/settings/data/backup.dart';
import 'package:lock_in/features/workout/data/workout_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('backs up every table with ms dates and enum names', () async {
    final at = DateTime(2026, 11, 3, 18, 30);
    final custom = await ExerciseRepository(db).create(
      const ExerciseDraft(
        name: 'Rope Hammer Curl',
        primaryMuscle: MuscleGroup.biceps,
        equipment: Equipment.cable,
        trackingType: TrackingType.weightReps,
      ),
    );
    final workouts = WorkoutRepository(db);
    final w = await workouts.start(name: 'Pull', now: at);
    final ex = await (db.select(
      db.exercises,
    )..where((e) => e.id.equals(custom))).getSingle();
    await workouts.addExercise(w, ex);
    await workouts.finish(w, now: at.add(const Duration(minutes: 40)));
    await FoodRepository(db).addEntry(
      kcal: 420,
      meal: Meal.lunch,
      at: at,
      name: 'Chicken biryani',
      proteinG: 22,
    );
    await FoodRepository(db).saveFood('Whey shake', 120, 24);
    await BodyRepository(db).logWeight(72.4, at);

    final backup =
        jsonDecode(await exportBackupJson(db)) as Map<String, dynamic>;
    expect(backup['app'], 'lock-in');
    expect(backup['format'], backupFormat);
    for (final table in [
      'userProfiles',
      'exercises',
      'workouts',
      'workoutExercises',
      'workoutSets',
      'bodyMeasurements',
      'foodEntries',
      'savedFoods',
      'routines',
      'routineExercises',
    ]) {
      expect(backup[table], isA<List<dynamic>>(), reason: table);
    }
    final food = (backup['foodEntries'] as List).single as Map;
    expect(food['loggedAt'], at.millisecondsSinceEpoch);
    expect(food['meal'], 'lunch');
    expect(food['name'], 'Chicken biryani');
    final rope = (backup['exercises'] as List).cast<Map>().singleWhere(
      (e) => e['name'] == 'Rope Hammer Curl',
    );
    expect(rope['trackingType'], 'weightReps');
    expect(rope['isCustom'], true);
    final workout = (backup['workouts'] as List).single as Map;
    expect(workout['status'], 'completed');
    expect(workout['durationSeconds'], 2400);
    expect((backup['bodyMeasurements'] as List).single['measuredValue'], 72.4);
    expect((backup['savedFoods'] as List).single['name'], 'Whey shake');
  });
}
