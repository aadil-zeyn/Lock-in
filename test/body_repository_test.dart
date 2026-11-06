import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/body/data/body_repository.dart';

void main() {
  late AppDatabase db;
  late BodyRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BodyRepository(db);
  });
  tearDown(() => db.close());

  final morning = DateTime(2026, 11, 6, 7, 30);

  test('logs a weight and rejects impossible values', () async {
    await repo.logWeight(78.4, morning);
    final rows = await db.select(db.bodyMeasurements).get();
    expect(rows.single.measuredValue, 78.4);
    expect(rows.single.measurementType, MeasurementType.bodyWeight);
    expect(() => repo.logWeight(5, morning), throwsArgumentError);
    expect(() => repo.logWeight(900, morning), throwsArgumentError);
  });

  test('Health Connect import skips readings already stored', () async {
    await repo.logWeight(78.4, morning);
    final added = await repo.importWeights([
      // Same weigh-in read back from Health Connect, 20 s apart.
      (at: morning.add(const Duration(seconds: 20)), kg: 78.4),
      (at: morning.add(const Duration(days: 1)), kg: 78.1),
      (at: morning.add(const Duration(days: 2)), kg: 77.9),
      (
        at: morning.add(const Duration(days: 2)),
        kg: 77.9,
      ), // duplicate in batch
      (at: morning.add(const Duration(days: 3)), kg: 2.0), // junk
    ]);
    expect(added, 2);
    expect(await db.select(db.bodyMeasurements).get(), hasLength(3));

    // Running the same sync again adds nothing.
    expect(
      await repo.importWeights([
        (at: morning.add(const Duration(days: 1)), kg: 78.1),
      ]),
      0,
    );
  });
}
