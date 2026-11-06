import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

/// Two readings this close together are treated as the same weigh-in
/// (e.g. one Lock-in wrote to Health Connect and then read back).
const sameReadingWindow = Duration(minutes: 1);

class BodyRepository {
  BodyRepository(this._db);
  final AppDatabase _db;

  /// Saves a body-weight entry. [kg] must be a plausible human weight.
  Future<int> logWeight(double kg, DateTime at) {
    if (kg < 20 || kg > 400) {
      throw ArgumentError('Weight must be between 20 and 400 kg');
    }
    return _db
        .into(_db.bodyMeasurements)
        .insert(
          BodyMeasurementsCompanion.insert(
            measurementType: MeasurementType.bodyWeight,
            measuredValue: kg,
            recordedAt: at,
          ),
        );
  }

  Future<void> deleteMeasurement(int id) =>
      (_db.delete(_db.bodyMeasurements)..where((m) => m.id.equals(id))).go();

  /// Adds readings that aren't already stored. Returns how many were new.
  Future<int> importWeights(Iterable<({DateTime at, double kg})> readings) {
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.bodyMeasurements)..where(
                (m) =>
                    m.measurementType.equalsValue(MeasurementType.bodyWeight),
              ))
              .get();
      final times = existing.map((m) => m.recordedAt).toList();
      var added = 0;
      for (final r in readings) {
        if (r.kg < 20 || r.kg > 400) continue;
        final dup = times.any(
          (t) => t.difference(r.at).abs() <= sameReadingWindow,
        );
        if (dup) continue;
        await _db
            .into(_db.bodyMeasurements)
            .insert(
              BodyMeasurementsCompanion.insert(
                measurementType: MeasurementType.bodyWeight,
                measuredValue: double.parse(r.kg.toStringAsFixed(2)),
                recordedAt: r.at,
              ),
            );
        times.add(r.at);
        added++;
      }
      return added;
    });
  }
}

final bodyRepositoryProvider = Provider<BodyRepository>(
  (ref) => BodyRepository(ref.watch(databaseProvider)),
);

/// Body-weight history, newest first.
final bodyWeightHistoryProvider = StreamProvider<List<BodyMeasurement>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.bodyMeasurements)
        ..where(
          (m) => m.measurementType.equalsValue(MeasurementType.bodyWeight),
        )
        ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)]))
      .watch();
});
