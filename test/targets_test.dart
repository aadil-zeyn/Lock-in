import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/settings/data/targets.dart';

void main() {
  test('Mifflin-St Jeor resting energy', () {
    // 10×80 + 6.25×180 − 5×25 + 5 = 1805
    expect(
      restingKcal(sex: Sex.male, weightKg: 80, heightCm: 180, age: 25),
      1805,
    );
    // 10×60 + 6.25×165 − 5×30 − 161 = 1320.25
    expect(
      restingKcal(sex: Sex.female, weightKg: 60, heightCm: 165, age: 30),
      closeTo(1320.25, 0.001),
    );
  });

  test('targets by goal, rounded', () {
    Targets t(WeightGoal g) => computeTargets(
      sex: Sex.male,
      weightKg: 80,
      heightCm: 180,
      age: 25,
      activity: ActivityLevel.moderate, // 1805 × 1.55 = 2797.75
      goal: g,
    );
    expect(t(WeightGoal.maintain), (
      kcal: 2800,
      protein: 145,
      maintenance: 2800,
    ));
    expect(t(WeightGoal.lose).kcal, 2250); // 2238 → 2250
    expect(t(WeightGoal.lose).protein, 160);
    expect(t(WeightGoal.gain).kcal, 3100); // 3077.5 → 3100
  });

  test('never below a safe floor', () {
    final t = computeTargets(
      sex: Sex.female,
      weightKg: 42,
      heightCm: 150,
      age: 60,
      activity: ActivityLevel.sedentary,
      goal: WeightGoal.lose,
    );
    expect(t.kcal, 1200);
  });

  test('lists what is missing', () {
    final now = DateTime(2026, 11, 7);
    final p = UserProfile(
      id: 1,
      heightCm: 178,
      weightUnit: WeightUnit.kg,
      lengthUnit: LengthUnit.cm,
      restTimerSeconds: 90,
      weeklyWorkoutGoal: 3,
      weeklyMinutesGoal: 180,
      weeklySetsGoal: 45,
      dailyKcalGoal: 2200,
      dailyProteinGoal: 140,
      sex: Sex.male,
      dailyStepsGoal: 8000,
      createdAt: now,
      updatedAt: now,
    );
    expect(missingForTargets(p, null), [
      'weight',
      'birth year',
      'activity level',
      'goal',
    ]);
    expect(targetsFor(p, 78, now), isNull);
  });
}
