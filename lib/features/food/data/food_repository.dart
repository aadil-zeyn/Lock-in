import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_format.dart';
import 'food_catalog.dart';

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
    this.carbsG = 0,
    this.fatG = 0,
  });
  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final Map<Meal, List<FoodEntry>> byMeal;

  int kcalFor(Meal m) => (byMeal[m] ?? const []).fold(0, (n, e) => n + e.kcal);
}

DayTotals totalsFor(List<FoodEntry> entries) {
  final byMeal = {for (final m in Meal.values) m: <FoodEntry>[]};
  var kcal = 0;
  var protein = 0.0, carbs = 0.0, fat = 0.0;
  for (final e in entries) {
    byMeal[e.meal]!.add(e);
    kcal += e.kcal;
    protein += e.proteinG ?? 0;
    carbs += e.carbsG ?? 0;
    fat += e.fatG ?? 0;
  }
  return DayTotals(
    kcal: kcal,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    byMeal: byMeal,
  );
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday" or "Friday, 6 November".
String dayLabel(DateTime day, DateTime now) {
  final d = dayStart(day), t = dayStart(now);
  if (d == t) return 'Today';
  if (d == t.subtract(const Duration(days: 1))) return 'Yesterday';
  return formatLongDate(d);
}

/// "1½", "2", "0.25" — servings as people write them.
String formatServings(double s) {
  final whole = s.truncate();
  final frac = s - whole;
  if (frac == 0) return '$whole';
  if (frac == 0.5) return whole == 0 ? '½' : '$whole½';
  return s.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// Entry name for a built-in food, e.g. "Puttu × 2" (just the name for 1).
String catalogEntryName(CatalogFood f, double servings) =>
    servings == 1 ? f.name : '${f.name} × ${formatServings(servings)}';

/// Reads servings written by [formatServings]: "2", "½", "1½", "0.25".
double? parseServings(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  if (t.endsWith('½')) {
    final whole = t.substring(0, t.length - 1);
    if (whole.isEmpty) return 0.5;
    final w = int.tryParse(whole);
    return w == null ? null : w + 0.5;
  }
  final v = double.tryParse(t);
  return v == null || v <= 0 ? null : v;
}

final Map<String, CatalogFood> _catalogByName = {
  for (final f in foodCatalog) f.name.toLowerCase(): f,
};

/// The built-in food (and servings) an entry was logged from, recognised by
/// its name as [catalogEntryName] writes it. Null for quick adds.
({CatalogFood food, double servings})? catalogPortionFor(String name) {
  final clean = name.trim();
  final exact = _catalogByName[clean.toLowerCase()];
  if (exact != null) return (food: exact, servings: 1);
  final m = RegExp(r'^(.+) × (\S+)$').firstMatch(clean);
  if (m == null) return null;
  final food = _catalogByName[m[1]!.trim().toLowerCase()];
  final servings = parseServings(m[2]!);
  if (food == null || servings == null) return null;
  return (food: food, servings: servings);
}

/// Nutrition of [servings] of a built-in food, macros to one decimal.
({int kcal, double protein, double carbs, double fat}) scaleCatalog(
  CatalogFood food,
  double servings,
) {
  final s = servings <= 0 ? 1.0 : servings;
  double r(double v) => double.parse((v * s).toStringAsFixed(1));
  return (
    kcal: (food.kcal * s).round(),
    protein: r(food.protein),
    carbs: r(food.carbs),
    fat: r(food.fat),
  );
}

class FoodRepository {
  FoodRepository(this._db);
  final AppDatabase _db;

  Future<int> addEntry({
    required int kcal,
    required Meal meal,
    required DateTime at,
    String name = '',
    double? proteinG,
    double? carbsG,
    double? fatG,
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
            carbsG: Value(carbsG),
            fatG: Value(fatG),
          ),
        );
  }

  /// Rewrites every field of an entry. [at] moves it to another day/time;
  /// null keeps the time it was logged at.
  Future<void> updateEntry(
    int id, {
    required int kcal,
    required Meal meal,
    String name = '',
    double? proteinG,
    double? carbsG,
    double? fatG,
    DateTime? at,
  }) async {
    final error = validateFoodValues(kcal, proteinG);
    if (error != null) throw ArgumentError(error);
    await (_db.update(_db.foodEntries)..where((e) => e.id.equals(id))).write(
      FoodEntriesCompanion(
        loggedAt: at == null ? const Value.absent() : Value(at),
        meal: Value(meal),
        name: Value(name.trim()),
        kcal: Value(kcal),
        proteinG: Value(proteinG),
        carbsG: Value(carbsG),
        fatG: Value(fatG),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteEntry(int id) =>
      (_db.delete(_db.foodEntries)..where((e) => e.id.equals(id))).go();

  Future<FoodEntry?> getEntry(int id) => (_db.select(
    _db.foodEntries,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Puts a deleted entry back exactly as it was (undo).
  Future<void> restoreEntry(FoodEntry entry) =>
      _db.into(_db.foodEntries).insert(entry, mode: InsertMode.insertOrReplace);

  /// Swaps an entry for [servings] of a built-in food, keeping its time.
  Future<void> replaceWithCatalog(
    int id,
    CatalogFood food,
    double servings,
    Meal meal,
  ) {
    final v = scaleCatalog(food, servings);
    return updateEntry(
      id,
      kcal: v.kcal,
      meal: meal,
      name: catalogEntryName(food, servings <= 0 ? 1 : servings),
      proteinG: v.protein,
      carbsG: v.carbs,
      fatG: v.fat,
    );
  }

  /// Saves (or updates, matching the name case-insensitively) a favourite.
  Future<int> saveFood(
    String name,
    int kcal,
    double? proteinG, {
    double? carbsG,
    double? fatG,
  }) async {
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
          carbsG: Value(carbsG),
          fatG: Value(fatG),
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
            carbsG: Value(carbsG),
            fatG: Value(fatG),
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
        carbsG: food.carbsG,
        fatG: food.fatG,
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

  /// Logs [servings] of a built-in food, scaling its nutrition.
  Future<int> logCatalog(
    CatalogFood food,
    double servings,
    Meal meal,
    DateTime at,
  ) {
    final s = servings <= 0 ? 1.0 : servings;
    final v = scaleCatalog(food, s);
    return addEntry(
      kcal: v.kcal,
      meal: meal,
      at: at,
      name: catalogEntryName(food, s),
      proteinG: v.protein,
      carbsG: v.carbs,
      fatG: v.fat,
    );
  }

  /// Edits a favourite in place (name included). Entries already logged
  /// from it keep their own values.
  Future<void> updateSaved(
    int id, {
    required String name,
    required int kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) throw ArgumentError('Give the food a name');
    final error = validateFoodValues(kcal, proteinG);
    if (error != null) throw ArgumentError(error);
    final clash =
        await (_db.select(_db.savedFoods)..where(
              (f) =>
                  f.name.lower().equals(clean.toLowerCase()) &
                  f.id.equals(id).not(),
            ))
            .getSingleOrNull();
    if (clash != null) {
      throw ArgumentError('You already have a favourite called $clean');
    }
    await (_db.update(_db.savedFoods)..where((f) => f.id.equals(id))).write(
      SavedFoodsCompanion(
        name: Value(clean),
        kcal: Value(kcal),
        proteinG: Value(proteinG),
        carbsG: Value(carbsG),
        fatG: Value(fatG),
      ),
    );
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
