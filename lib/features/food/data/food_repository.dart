import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const maxKcalPerEntry = 10000;
const maxProteinPerEntry = 500.0;

/// Null when valid, otherwise a message for the form.
String? validateFoodValues(int? kcal, double? protein) {
  if (kcal == null || kcal <= 0) return 'Enter the calories (kcal)';
  if (kcal > maxKcalPerEntry) return 'That\'s over $maxKcalPerEntry kcal';
  if (protein != null && (protein < 0 || protein > maxProteinPerEntry)) {
    return 'Protein looks off — check the grams';
  }
  return null;
}

class DayTotals {
  const DayTotals({
    required this.kcal,
    required this.proteinG,
    required this.byMeal,
  });
  final int kcal;
  final double proteinG;
  final Map<Meal, List<FoodEntry>> byMeal;

  int kcalFor(Meal m) => (byMeal[m] ?? const []).fold(0, (n, e) => n + e.kcal);
}

DayTotals totalsFor(List<FoodEntry> entries) {
  final byMeal = {for (final m in Meal.values) m: <FoodEntry>[]};
  var kcal = 0;
  var protein = 0.0;
  for (final e in entries) {
    byMeal[e.meal]!.add(e);
    kcal += e.kcal;
    protein += e.proteinG ?? 0;
  }
  return DayTotals(kcal: kcal, proteinG: protein, byMeal: byMeal);
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

class FoodRepository {
  FoodRepository(this._db);
  final AppDatabase _db;

  Future<int> addEntry({
    required int kcal,
    required Meal meal,
    required DateTime at,
    String name = '',
    double? proteinG,
  }) {
    final error = validateFoodValues(kcal, proteinG);
    if (error != null) throw ArgumentError(error);
    return _db
        .into(_db.foodEntries)
        .insert(
          FoodEntriesCompanion.insert(
            loggedAt: at,
            meal: meal,
            name: Value(name.trim()),
            kcal: kcal,
            proteinG: Value(proteinG),
          ),
        );
  }

  Future<void> updateEntry(
    int id, {
    required int kcal,
    required Meal meal,
    String name = '',
    double? proteinG,
  }) async {
    final error = validateFoodValues(kcal, proteinG);
    if (error != null) throw ArgumentError(error);
    await (_db.update(_db.foodEntries)..where((e) => e.id.equals(id))).write(
      FoodEntriesCompanion(
        meal: Value(meal),
        name: Value(name.trim()),
        kcal: Value(kcal),
        proteinG: Value(proteinG),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteEntry(int id) =>
      (_db.delete(_db.foodEntries)..where((e) => e.id.equals(id))).go();

  /// Saves (or updates, matching the name case-insensitively) a favourite.
  Future<int> saveFood(String name, int kcal, double? proteinG) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) throw ArgumentError('Give the food a name');
    final error = validateFoodValues(kcal, proteinG);
    if (error != null) throw ArgumentError(error);
    final existing =
        await (_db.select(_db.savedFoods)
              ..where((f) => f.name.lower().equals(clean.toLowerCase())))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.savedFoods,
      )..where((f) => f.id.equals(existing.id))).write(
        SavedFoodsCompanion(
          name: Value(clean),
          kcal: Value(kcal),
          proteinG: Value(proteinG),
        ),
      );
      return existing.id;
    }
    return _db
        .into(_db.savedFoods)
        .insert(
          SavedFoodsCompanion.insert(
            name: clean,
            kcal: kcal,
            proteinG: Value(proteinG),
          ),
        );
  }

  /// Logs a favourite and bumps it up the list.
  Future<int> logSaved(SavedFood food, Meal meal, DateTime at) {
    return _db.transaction(() async {
      final id = await addEntry(
        kcal: food.kcal,
        meal: meal,
        at: at,
        name: food.name,
        proteinG: food.proteinG,
      );
      await (_db.update(
        _db.savedFoods,
      )..where((f) => f.id.equals(food.id))).write(
        SavedFoodsCompanion(
          useCount: Value(food.useCount + 1),
          lastUsedAt: Value(DateTime.now()),
        ),
      );
      return id;
    });
  }

  Future<void> deleteSaved(int id) =>
      (_db.delete(_db.savedFoods)..where((f) => f.id.equals(id))).go();

  Stream<List<FoodEntry>> watchDay(DateTime day) {
    final start = dayStart(day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.foodEntries)
          ..where(
            (e) =>
                e.loggedAt.isBiggerOrEqualValue(start) &
                e.loggedAt.isSmallerThanValue(end),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.loggedAt)]))
        .watch();
  }

  Stream<List<SavedFood>> watchSaved() =>
      (_db.select(_db.savedFoods)..orderBy([
            (f) => OrderingTerm.desc(f.useCount),
            (f) => OrderingTerm.desc(f.lastUsedAt),
            (f) => OrderingTerm.asc(f.name),
          ]))
          .watch();

  Future<void> setGoals({int? kcal, int? protein}) async {
    await (_db.update(_db.userProfiles)..where((p) => p.id.equals(1))).write(
      UserProfilesCompanion(
        dailyKcalGoal: kcal == null ? const Value.absent() : Value(kcal),
        dailyProteinGoal: protein == null
            ? const Value.absent()
            : Value(protein),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => FoodRepository(ref.watch(databaseProvider)),
);

/// Entries for one calendar day, oldest first.
final dayFoodProvider = StreamProvider.autoDispose
    .family<List<FoodEntry>, DateTime>(
      (ref, day) => ref.watch(foodRepositoryProvider).watchDay(day),
    );

final savedFoodsProvider = StreamProvider<List<SavedFood>>(
  (ref) => ref.watch(foodRepositoryProvider).watchSaved(),
);
