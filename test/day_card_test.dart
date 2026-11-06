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

  group('summarizeSets', () {
    final t0 = DateTime(2026, 1, 1);
    WorkoutSet s(
      double? kg,
      int? reps, {
      SetType type = SetType.normal,
      bool done = true,
      int? secs,
      BandLevel? band,
    }) => WorkoutSet(
      id: 0,
      workoutExerciseId: 0,
      setNumber: 1,
      setType: type,
      weightKg: kg,
      reps: reps,
      durationSeconds: secs,
      bandLevel: band,
      isCompleted: done,
      createdAt: t0,
      updatedAt: t0,
    );

    test('weight × reps: sets, rep range, top weight; warm-ups ignored', () {
      expect(
        summarizeSets(
          [
            s(40, 12, type: SetType.warmup),
            s(60, 8),
            s(60, 8),
            s(62.5, 6),
            s(70, 5, done: false),
          ],
          TrackingType.weightReps,
          WeightUnit.kg,
        ),
        '3 × 6–8 · 62.5 kg',
      );
      expect(
        summarizeSets(
          [s(60, 10), s(60, 10)],
          TrackingType.weightReps,
          WeightUnit.lb,
        ),
        '2 × 10 · 132.3 lb',
      );
    });

    test('bodyweight, assisted, timed and band', () {
      expect(
        summarizeSets(
          [s(null, 12), s(null, 10)],
          TrackingType.bodyweightReps,
          WeightUnit.kg,
        ),
        '2 × 10–12',
      );
      expect(
        summarizeSets([s(10, 8)], TrackingType.bodyweightReps, WeightUnit.kg),
        '1 × 8 · +10 kg',
      );
      expect(
        summarizeSets(
          [s(-20, 8)],
          TrackingType.assistedBodyweight,
          WeightUnit.kg,
        ),
        '1 × 8 · −20 kg',
      );
      expect(
        summarizeSets(
          [s(null, null, secs: 45), s(null, null, secs: 60)],
          TrackingType.duration,
          WeightUnit.kg,
        ),
        '2 × 45–60 s',
      );
      expect(
        summarizeSets(
          [
            s(null, 15, band: BandLevel.medium),
            s(null, 12, band: BandLevel.heavy),
          ],
          TrackingType.bandReps,
          WeightUnit.kg,
        ),
        '2 × 12–15 · Heavy',
      );
    });

    test('nothing done → null', () {
      expect(
        summarizeSets(
          [s(60, 8, done: false)],
          TrackingType.weightReps,
          WeightUnit.kg,
        ),
        isNull,
      );
    });
  });
}
