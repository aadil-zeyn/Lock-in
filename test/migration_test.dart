import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/core/database/seed_exercises.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;

/// Every schema step must keep real users' data. Schemas are dumped to
/// `drift_schemas/` with `dart run drift_dev schema dump` before each change.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v1 → v2 produces exactly the v2 schema', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
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
