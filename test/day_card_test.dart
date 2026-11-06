import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/share/data/day_card.dart';

void main() {
  test('day of the year', () {
    expect(dayOfYear(DateTime(2026, 1, 1)), 1);
    expect(dayOfYear(DateTime(2026, 11, 7, 23, 59)), 311);
    expect(dayOfYear(DateTime(2026, 12, 31)), 365);
    expect(dayOfYear(DateTime(2028, 12, 31)), 366); // leap year
    expect(daysInYear(2026), 365);
    expect(daysInYear(2028), 366);
  });

  test('steps streak counts back from today', () {
    const goal = 10000;
    expect(
      stepsStreak([12000, 10500, 11000, 4000], goal),
      3,
      reason: 'today not reached yet: streak runs to yesterday',
    );
    expect(stepsStreak([12000, 10500, 11000, 10200], goal), 4);
    expect(stepsStreak([12000, 3000, 11000, 10200], goal), 2);
    expect(stepsStreak([3000, 2000], goal), 0);
    expect(stepsStreak([], goal), 0);
  });

  test('calories on target depends on the goal', () {
    expect(caloriesOnTarget(0, 2200, WeightGoal.maintain), isFalse);
    expect(caloriesOnTarget(2150, 2200, WeightGoal.maintain), isTrue);
    expect(caloriesOnTarget(2600, 2200, WeightGoal.maintain), isFalse);
    expect(caloriesOnTarget(2000, 2200, WeightGoal.lose), isTrue);
    expect(caloriesOnTarget(2400, 2200, WeightGoal.lose), isFalse);
    expect(caloriesOnTarget(2900, 2800, WeightGoal.gain), isTrue);
    expect(caloriesOnTarget(2200, 2800, WeightGoal.gain), isFalse);
  });
}
