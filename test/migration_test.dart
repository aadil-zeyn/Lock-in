import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/core/database/seed_exercises.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;

/// Every schema step must keep real users' data. Schemas are dumped to
/// `drift_schemas/` with `dart run drift_dev schema dump` before each change.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  for (final from in [1, 2, 3]) {
    test('v$from → v4 produces exactly the v4 schema', () async {
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    });
  }

  test('v3 → v4 keeps food entries and adds empty macros', () async {
    final schema = await verifier.schemaAt(3);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await old.customStatement(
      "INSERT INTO food_entries (id, logged_at, meal, name, kcal, protein_g, "
      "created_at, updated_at) VALUES (1, 1793980000, 'lunch', 'Biryani', "
      "600, 28.0, 0, 0)",
    );
    await old.customStatement(
      "INSERT INTO saved_foods (id, name, kcal, protein_g, use_count, "
      "created_at) VALUES (1, 'Shake', 180, 30.0, 4, 0)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    final e = await db.select(db.foodEntries).getSingle();
    expect((e.name, e.kcal, e.proteinG), ('Biryani', 600, 28.0));
    expect((e.carbsG, e.fatG), (null, null));
    final f = await db.select(db.savedFoods).getSingle();
    expect((f.name, f.useCount, f.carbsG), ('Shake', 4, null));
    await db.close();
  });

  test('v2 → v3 keeps the profile and adds food goals', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old.customStatement(
      "INSERT INTO user_profiles (id, name, weight_unit, length_unit, "
      "rest_timer_seconds, weekly_workout_goal, weekly_minutes_goal, "
      "weekly_sets_goal, created_at, updated_at) VALUES "
      "(1, 'Aadil', 'kg', 'cm', 120, 4, 200, 50, 0, 0)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    final p = await db.select(db.userProfiles).getSingle();
    expect(p.name, 'Aadil');
    expect(p.restTimerSeconds, 120);
    expect(p.weeklyWorkoutGoal, 4);
    expect(p.dailyKcalGoal, 2200);
    expect(p.dailyProteinGoal, 140);
    // Food tables exist and work.
    await db
        .into(db.foodEntries)
        .insert(
          FoodEntriesCompanion.insert(
            loggedAt: DateTime(2026, 11, 6, 13),
            meal: Meal.lunch,
            kcal: 650,
          ),
        );
    expect(await db.select(db.foodEntries).get(), hasLength(1));
    await db.close();
  });

  test('v1 → v2 keeps logged sets and adds band exercises once', () async {
    final schema = await verifier.schemaAt(1);

    // A v1 database as it exists on a phone: a user exercise that clashes
    // with a new band name, and a logged workout.
    final old = v1.DatabaseAtV1(schema.newConnection());
    Future<void> sql(String s) => old.customStatement(s);
    await sql(
      "INSERT INTO exercises (id, name, primary_muscle, secondary_muscles, "
      "equipment, tracking_type, is_custom, created_at, updated_at) VALUES "
      "(1, 'Band Row', 'back', '', 'band', 'weightReps', 1, 0, 0)",
    );
    await sql(
      "INSERT INTO workouts (id, name, status, started_at, created_at, "
      "updated_at) VALUES (1, 'Pull', 'completed', 1793000000, 0, 0)",
    );
    await sql(
      "INSERT INTO workout_exercises (id, workout_id, exercise_id, "
      "exercise_name_snapshot, position) VALUES (1, 1, 1, 'Band Row', 0)",
    );
    await sql(
      "INSERT INTO workout_sets (id, workout_exercise_id, set_number, "
      "set_type, weight_kg, reps, is_completed, created_at, updated_at) "
      "VALUES (1, 1, 1, 'normal', 20.0, 12, 1, 0, 0)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    final set = await db.select(db.workoutSets).getSingle();
    expect(set.reps, 12);
    expect(set.weightKg, 20.0);
    expect(set.bandLevel, isNull);

    final bands = await (db.select(
      db.exercises,
    )..where((e) => e.equipment.equalsValue(Equipment.band))).get();
    final names = bands.map((e) => e.name.toLowerCase()).toList();
    expect(names.toSet(), hasLength(names.length), reason: 'no duplicates');
    expect(names, hasLength(bandSeedExercises().length));
    // The user's own "Band Row" is kept as it was, not replaced.
    final row = bands.firstWhere((e) => e.name == 'Band Row');
    expect(row.isCustom, isTrue);
    expect(row.trackingType, TrackingType.weightReps);
    await db.close();
  });

  test('band exercises are logged by band, not by weight', () {
    final bands = bandSeedExercises();
    expect(bands, hasLength(16));
    expect(
      bands.every((e) => e.trackingType.value == TrackingType.bandReps),
      isTrue,
    );
    // Fresh installs get them through the normal seed list.
    expect(seedExercises().length, 52 + 16);
  });
}
