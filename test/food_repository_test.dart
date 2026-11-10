import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/food/data/food_catalog.dart';
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

  test('built-in foods scale by servings, with macros in the totals', () async {
    final puttu = foodCatalog.firstWhere((f) => f.name == 'Puttu');
    final egg = foodCatalog.firstWhere((f) => f.name == 'Boiled egg');
    await repo.logCatalog(puttu, 2, Meal.breakfast, noon);
    await repo.logCatalog(egg, 1.5, Meal.breakfast, noon);
    final rows = await repo.watchDay(noon).first;
    expect(rows.map((e) => e.name), ['Puttu × 2', 'Boiled egg × 1½']);
    expect(rows.first.kcal, puttu.kcal * 2);
    expect(rows.first.carbsG, puttu.carbs * 2);
    final t = totalsFor(rows);
    expect(t.kcal, puttu.kcal * 2 + (egg.kcal * 1.5).round());
    expect(t.fatG, closeTo(puttu.fat * 2 + egg.fat * 1.5, 0.11));
  });

  test('servings read naturally', () {
    expect(formatServings(1), '1');
    expect(formatServings(0.5), '½');
    expect(formatServings(2.5), '2½');
  });

  test('servings parse back from what formatServings writes', () {
    for (final s in [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 10.0]) {
      expect(parseServings(formatServings(s)), s);
    }
    expect(parseServings(''), isNull);
    expect(parseServings('abc'), isNull);
    expect(parseServings('0'), isNull);
  });

  test('a logged built-in food is recognised from its entry name', () {
    final puttu = foodCatalog.firstWhere((f) => f.name == 'Puttu');
    expect(catalogPortionFor('Puttu')?.food, puttu);
    expect(catalogPortionFor('Puttu')?.servings, 1);
    final two = catalogPortionFor(catalogEntryName(puttu, 2.5));
    expect((two?.food, two?.servings), (puttu, 2.5));
    expect(catalogPortionFor('Mum\'s curry'), isNull);
    expect(catalogPortionFor('Mum\'s curry × 2'), isNull);
    expect(catalogPortionFor(''), isNull);
  });

  test('built-in food names are unique (edit relies on it)', () {
    final names = foodCatalog.map((f) => f.name.toLowerCase()).toList();
    expect(names.toSet().length, names.length);
  });

  test('editing can move an entry to another day and time', () async {
    final id = await repo.addEntry(kcal: 300, meal: Meal.snack, at: noon);
    final yesterdayEvening = DateTime(2026, 11, 5, 20, 15);
    await repo.updateEntry(
      id,
      kcal: 300,
      meal: Meal.dinner,
      at: yesterdayEvening,
    );
    expect(await repo.watchDay(noon).first, isEmpty);
    final moved = await repo.watchDay(yesterdayEvening).first;
    expect(
      (moved.single.loggedAt, moved.single.meal),
      (yesterdayEvening, Meal.dinner),
    );

    // Without `at` the time is left alone.
    await repo.updateEntry(id, kcal: 320, meal: Meal.dinner);
    expect((await repo.getEntry(id))!.loggedAt, yesterdayEvening);
  });

  test('a deleted entry can be restored exactly (undo)', () async {
    final id = await repo.addEntry(
      kcal: 410,
      meal: Meal.lunch,
      at: noon,
      name: 'Wrap',
      proteinG: 22,
      carbsG: 40,
      fatG: 12,
    );
    final before = (await repo.getEntry(id))!;
    await repo.deleteEntry(id);
    expect(await repo.getEntry(id), isNull);
    await repo.restoreEntry(before);
    expect(await repo.getEntry(id), before);
  });

  test('an entry can be swapped for a different built-in food', () async {
    final puttu = foodCatalog.firstWhere((f) => f.name == 'Puttu');
    final egg = foodCatalog.firstWhere((f) => f.name == 'Boiled egg');
    final id = await repo.logCatalog(puttu, 1, Meal.breakfast, noon);
    await repo.replaceWithCatalog(id, egg, 3, Meal.breakfast);
    final e = (await repo.getEntry(id))!;
    expect(e.name, 'Boiled egg × 3');
    expect(e.kcal, egg.kcal * 3);
    expect(e.proteinG, closeTo(egg.protein * 3, 0.051));
    expect(e.loggedAt, noon, reason: 'keeps its time');
  });

  test('favourites can be edited and renamed, but not onto another', () async {
    final shake = await repo.saveFood('Protein shake', 180, 30);
    await repo.saveFood('Banana', 105, 1.3);
    await repo.updateSaved(
      shake,
      name: 'Whey shake',
      kcal: 140,
      proteinG: 25,
      carbsG: 3,
      fatG: 2,
    );
    final saved = await repo.watchSaved().first;
    final s = saved.firstWhere((f) => f.id == shake);
    expect(
      (s.name, s.kcal, s.proteinG, s.carbsG, s.fatG),
      ('Whey shake', 140, 25.0, 3.0, 2.0),
    );
    expect(
      () => repo.updateSaved(shake, name: 'banana', kcal: 100),
      throwsArgumentError,
    );
    // Changing only the letter case of its own name is fine.
    await repo.updateSaved(shake, name: 'WHEY shake', kcal: 140);
  });

  test('day labels', () {
    final now = DateTime(2026, 11, 10, 9);
    expect(dayLabel(DateTime(2026, 11, 10, 23), now), 'Today');
    expect(dayLabel(DateTime(2026, 11, 9, 1), now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 11, 6), now), 'Friday, 6 November');
  });

  test('goals are saved on the profile', () async {
    await repo.setGoals(kcal: 2600, protein: 160);
    final p = await db.select(db.userProfiles).getSingle();
    expect((p.dailyKcalGoal, p.dailyProteinGoal), (2600, 160));
  });
}
