import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/food/data/food_repository.dart';

void main() {
  late AppDatabase db;
  late FoodRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FoodRepository(db);
  });
  tearDown(() => db.close());

  final noon = DateTime(2026, 11, 6, 12, 30);

  test('meal defaults follow the time of day', () {
    expect(Meal.forTime(DateTime(2026, 1, 1, 8)), Meal.breakfast);
    expect(Meal.forTime(DateTime(2026, 1, 1, 13)), Meal.lunch);
    expect(Meal.forTime(DateTime(2026, 1, 1, 19)), Meal.dinner);
    expect(Meal.forTime(DateTime(2026, 1, 1, 22)), Meal.snack);
  });

  test('validation', () {
    expect(validateFoodValues(null, null), isNotNull);
    expect(validateFoodValues(0, null), isNotNull);
    expect(validateFoodValues(20000, null), isNotNull);
    expect(validateFoodValues(500, -3), isNotNull);
    expect(validateFoodValues(500, 35), isNull);
  });

  test('a day only includes that calendar day, totals add up', () async {
    await repo.addEntry(
      kcal: 450,
      meal: Meal.breakfast,
      at: DateTime(2026, 11, 6, 7),
      proteinG: 30,
    );
    await repo.addEntry(
      kcal: 700,
      meal: Meal.lunch,
      at: noon,
      name: 'Chicken rice',
      proteinG: 45,
    );
    await repo.addEntry(
      kcal: 200,
      meal: Meal.snack,
      at: DateTime(2026, 11, 6, 23, 59),
    );
    await repo.addEntry(
      kcal: 999,
      meal: Meal.dinner,
      at: DateTime(2026, 11, 7, 0, 1),
    );

    final day = await repo.watchDay(noon).first;
    final t = totalsFor(day);
    expect(t.kcal, 1350);
    expect(t.proteinG, 75);
    expect(t.kcalFor(Meal.lunch), 700);
    expect(t.byMeal[Meal.dinner], isEmpty);
  });

  test('edit and delete an entry', () async {
    final id = await repo.addEntry(kcal: 300, meal: Meal.snack, at: noon);
    await repo.updateEntry(id, kcal: 350, meal: Meal.lunch, name: ' Wrap ');
    var e = await db.select(db.foodEntries).getSingle();
    expect((e.kcal, e.meal, e.name), (350, Meal.lunch, 'Wrap'));
    await repo.deleteEntry(id);
    expect(await db.select(db.foodEntries).get(), isEmpty);
  });

  test('favourites: save updates by name, logging bumps use count', () async {
    final a = await repo.saveFood('Protein shake', 180, 30);
    final b = await repo.saveFood('protein  SHAKE', 200, 32);
    expect(b, a, reason: 'same name updates instead of duplicating');
    await repo.saveFood('Banana', 105, 1.3);

    var saved = await repo.watchSaved().first;
    final shake = saved.firstWhere((f) => f.name == 'protein SHAKE');
    expect(shake.kcal, 200);
    await repo.logSaved(shake, Meal.snack, noon);

    saved = await repo.watchSaved().first;
    expect(saved.first.id, shake.id, reason: 'most used first');
    expect(saved.first.useCount, 1);
    final logged = await db.select(db.foodEntries).getSingle();
    expect(
      (logged.name, logged.kcal, logged.proteinG),
      ('protein SHAKE', 200, 32.0),
    );
  });

  test('goals are saved on the profile', () async {
    await repo.setGoals(kcal: 2600, protein: 160);
    final p = await db.select(db.userProfiles).getSingle();
    expect((p.dailyKcalGoal, p.dailyProteinGoal), (2600, 160));
  });
}
