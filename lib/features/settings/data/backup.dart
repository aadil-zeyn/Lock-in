import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Version of the backup layout below. Bump it when a table's shape changes.
const backupFormat = 1;

/// Every table, row by row, as JSON: the user's whole Lock-in, ready to be
/// restored by another install (or the Kotlin app's Backup & restore).
///
/// Layout: an object with `app` ("lock-in"), `format`, `source`
/// ("flutter"), `exportedAt` (ms) and one list per table, keyed by table
/// name (`workouts`, `foodEntries`, …). Each row is Drift's `toJson()`:
/// camelCase column names, dates as epoch **milliseconds**, enums by name
/// ("weightReps", "breakfast"), nulls kept.
Future<Map<String, Object?>> buildBackup(
  AppDatabase db, {
  DateTime? now,
}) async {
  final serializer = ValueSerializer.defaults();
  List<Map<String, dynamic>> rows(List<DataClass> list) => [
    for (final r in list) r.toJson(serializer: serializer),
  ];
  return {
    'app': 'lock-in',
    'format': backupFormat,
    'source': 'flutter',
    'exportedAt': (now ?? DateTime.now()).millisecondsSinceEpoch,
    'userProfiles': rows(await db.select(db.userProfiles).get()),
    'exercises': rows(await db.select(db.exercises).get()),
    'workouts': rows(await db.select(db.workouts).get()),
    'workoutExercises': rows(await db.select(db.workoutExercises).get()),
    'workoutSets': rows(await db.select(db.workoutSets).get()),
    'bodyMeasurements': rows(await db.select(db.bodyMeasurements).get()),
    'foodEntries': rows(await db.select(db.foodEntries).get()),
    'savedFoods': rows(await db.select(db.savedFoods).get()),
    'routines': rows(await db.select(db.routines).get()),
    'routineExercises': rows(await db.select(db.routineExercises).get()),
  };
}

/// The backup as a compact JSON string.
Future<String> exportBackupJson(AppDatabase db) async =>
    jsonEncode(await buildBackup(db));
