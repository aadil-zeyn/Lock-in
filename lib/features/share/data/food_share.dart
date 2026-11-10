import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../food/data/food_repository.dart';
import 'day_card.dart';

/// One meal on the food story card.
typedef FoodShareMeal = ({Meal meal, int kcal, List<String> items});

/// Numbers for the "Food" story card: one day's eating.
class FoodShare {
  const FoodShare({
    required this.day,
    required this.kcal,
    required this.kcalGoal,
    required this.proteinG,
    required this.proteinGoal,
    required this.carbsG,
    required this.fatG,
    required this.kcalOk,
    required this.meals,
    required this.weekKcal,
    required this.loggedStreak,
    required this.entryCount,
  });

  final DateTime day;
  final int kcal;
  final int kcalGoal;
  final int proteinG;
  final int proteinGoal;
  final int carbsG;
  final int fatG;

  /// Calories match the goal for the user's weight goal ([caloriesOnTarget]).
  final bool kcalOk;

  /// Meals with something logged, breakfast first.
  final List<FoodShareMeal> meals;

  /// kcal for the 7 days ending on [day], oldest first.
  final List<int> weekKcal;

  /// Consecutive days with food logged, ending on [day].
  final int loggedStreak;
  final int entryCount;

  bool get isEmpty => entryCount == 0;
  bool get proteinOk => proteinGoal > 0 && proteinG >= proteinGoal;
}

/// Builds the card from every entry between 60 days before [day] and the
/// end of [day]. Entries after [day] are ignored.
FoodShare computeFoodShare({
  required List<FoodEntry> entries,
  required DateTime day,
  required int kcalGoal,
  required int proteinGoal,
  WeightGoal? weightGoal,
}) {
  final start = dayStart(day);
  final end = start.add(const Duration(days: 1));

  final perDay = <DateTime, int>{};
  final todays = <FoodEntry>[];
  for (final e in entries) {
    if (!e.loggedAt.isBefore(end)) continue;
    final d = dayStart(e.loggedAt);
    perDay[d] = (perDay[d] ?? 0) + e.kcal;
    if (d == start) todays.add(e);
  }
  todays.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  final totals = totalsFor(todays);

  // DateTime(y, m, d - i) stays on midnight across DST changes.
  DateTime back(int i) => DateTime(start.year, start.month, start.day - i);

  var streak = 0;
  while (perDay.containsKey(back(streak))) {
    streak++;
  }

  return FoodShare(
    day: start,
    kcal: totals.kcal,
    kcalGoal: kcalGoal,
    proteinG: totals.proteinG.round(),
    proteinGoal: proteinGoal,
    carbsG: totals.carbsG.round(),
    fatG: totals.fatG.round(),
    kcalOk: caloriesOnTarget(totals.kcal, kcalGoal, weightGoal),
    meals: [
      for (final m in Meal.values)
        if (totals.byMeal[m]!.isNotEmpty)
          (
            meal: m,
            kcal: totals.kcalFor(m),
            items: [
              for (final e in totals.byMeal[m]!)
                e.name.isEmpty ? 'Quick add' : e.name,
            ],
          ),
    ],
    weekKcal: [for (var i = 6; i >= 0; i--) perDay[back(i)] ?? 0],
    loggedStreak: streak,
    entryCount: todays.length,
  );
}

/// The food card for a calendar day (time of day is ignored).
final foodShareProvider = FutureProvider.autoDispose
    .family<FoodShare, DateTime>((ref, day) async {
      final db = ref.watch(databaseProvider);
      final start = dayStart(day);
      final from = DateTime(start.year, start.month, start.day - 60);
      final end = start.add(const Duration(days: 1));

      final profile = await (db.select(
        db.userProfiles,
      )..where((p) => p.id.equals(1))).getSingle();
      final entries =
          await (db.select(db.foodEntries)..where(
                (f) =>
                    f.loggedAt.isBiggerOrEqualValue(from) &
                    f.loggedAt.isSmallerThanValue(end),
              ))
              .get();

      return computeFoodShare(
        entries: entries,
        day: start,
        kcalGoal: profile.dailyKcalGoal,
        proteinGoal: profile.dailyProteinGoal,
        weightGoal: profile.weightGoal,
      );
    });
