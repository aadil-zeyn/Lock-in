import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/share/data/food_share.dart';
import 'package:lock_in/features/share/presentation/story_cards.dart';

void main() {
  final day = DateTime(2026, 11, 10, 21); // Tuesday evening
  var nextId = 0;

  FoodEntry entry(
    DateTime at,
    int kcal, {
    Meal meal = Meal.lunch,
    String name = '',
    double? protein,
    double? carbs,
    double? fat,
  }) => FoodEntry(
    id: nextId++,
    loggedAt: at,
    meal: meal,
    name: name,
    kcal: kcal,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    createdAt: at,
    updatedAt: at,
  );

  DateTime on(int daysBack, [int hour = 13]) =>
      DateTime(2026, 11, 10 - daysBack, hour);

  test('totals, meals in order and quick adds named', () {
    final s = computeFoodShare(
      entries: [
        entry(on(0, 20), 650, meal: Meal.dinner, name: 'Chicken biryani'),
        entry(on(0, 8), 420, meal: Meal.breakfast, name: 'Puttu × 2'),
        entry(on(0, 9), 180, meal: Meal.breakfast, protein: 12.4),
        entry(on(0, 13), 560, protein: 38.6, carbs: 60, fat: 14.5),
        entry(on(1), 2100), // yesterday: not in today's totals
        entry(DateTime(2026, 11, 11, 0, 5), 999), // after the day: ignored
      ],
      day: day,
      kcalGoal: 2200,
      proteinGoal: 140,
      weightGoal: WeightGoal.maintain,
    );
    expect(s.day, DateTime(2026, 11, 10));
    expect(s.kcal, 1810);
    expect(s.proteinG, 51);
    expect(s.carbsG, 60);
    expect(s.fatG, 15);
    expect(s.entryCount, 4);
    expect(s.kcalOk, isFalse);
    expect(s.proteinOk, isFalse);
    expect(s.meals.map((m) => m.meal), [
      Meal.breakfast,
      Meal.lunch,
      Meal.dinner,
    ]);
    expect(s.meals.first.items, ['Puttu × 2', 'Quick add']);
    expect(s.meals.first.kcal, 600);
  });

  test('last 7 days and logging streak end on the shared day', () {
    final s = computeFoodShare(
      entries: [
        entry(on(0), 2000),
        entry(on(1), 1800),
        entry(on(1, 20), 300),
        entry(on(2), 2400),
        // gap on day 3
        entry(on(4), 1500),
        entry(on(9), 1900),
      ],
      day: day,
      kcalGoal: 2200,
      proteinGoal: 140,
    );
    expect(s.weekKcal, [0, 0, 1500, 0, 2400, 2100, 2000]);
    expect(s.loggedStreak, 3);
    expect(s.kcalOk, isTrue);
  });

  test('a day with nothing logged is empty with no streak', () {
    final s = computeFoodShare(
      entries: [entry(on(1), 1800)],
      day: day,
      kcalGoal: 2200,
      proteinGoal: 140,
    );
    expect(s.isEmpty, isTrue);
    expect(s.meals, isEmpty);
    expect(s.loggedStreak, 0);
  });

  // Overflows throw in widget tests: the card must fit a full day with
  // every meal, long names and big numbers, and a nearly empty one.
  testWidgets('food card lays out on any day', (tester) async {
    final full = computeFoodShare(
      entries: [
        for (final m in Meal.values)
          for (var i = 0; i < 4; i++)
            entry(
              on(0, 8 + i),
              1450,
              meal: m,
              name: 'Kerala parotta with beef fry and extra gravy × 3',
              protein: 60,
              carbs: 180,
              fat: 70,
            ),
        for (var i = 1; i < 30; i++) entry(on(i), 3100),
      ],
      day: day,
      kcalGoal: 2200,
      proteinGoal: 140,
    );
    final light = computeFoodShare(
      entries: [entry(on(0), 90, meal: Meal.snack)],
      day: day,
      kcalGoal: 0,
      proteinGoal: 0,
    );
    for (final d in [full, light]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox.fromSize(
                size: storySize,
                child: FoodStoryCard(data: d),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
    expect(find.textContaining('Lunch', findRichText: true), findsNothing);
    expect(find.textContaining('Snacks', findRichText: true), findsOneWidget);
  });
}
