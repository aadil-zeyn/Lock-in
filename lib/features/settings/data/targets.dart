import '../../../core/database/app_database.dart';

/// Suggested daily calories and protein from the profile.
///
/// Calories: Mifflin-St Jeor resting energy × activity multiplier, then the
/// goal's adjustment (−20% to lose, +10% to gain), rounded to 50 kcal.
/// Protein: grams per kg of body weight for the goal, rounded to 5 g.
/// These are starting points — adjust after 2–3 weeks of weigh-ins.
typedef Targets = ({int kcal, int protein, int maintenance});

int ageOn(int birthYear, DateTime now) => now.year - birthYear;

/// Resting energy (kcal/day), Mifflin-St Jeor.
double restingKcal({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) => 10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

Targets computeTargets({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
  required ActivityLevel activity,
  required WeightGoal goal,
}) {
  final maintenance =
      restingKcal(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age) *
      activity.multiplier;
  int round(double v, int step) => (v / step).round() * step;
  // Never suggest below a safe floor, whatever the inputs.
  final floor = sex == Sex.male ? 1500 : 1200;
  final kcal = round(maintenance * (1 + goal.kcalAdjust), 50);
  return (
    kcal: kcal < floor ? floor : kcal,
    protein: round(weightKg * goal.proteinPerKg, 5),
    maintenance: round(maintenance, 50),
  );
}

/// What's still needed before targets can be suggested, or empty.
List<String> missingForTargets(UserProfile p, double? latestWeightKg) => [
  if (p.heightCm == null) 'height',
  if (latestWeightKg == null) 'weight',
  if (p.sex == null) 'sex',
  if (p.birthYear == null) 'birth year',
  if (p.activityLevel == null) 'activity level',
  if (p.weightGoal == null) 'goal',
];

/// Suggested targets for [p], or null while something is missing.
Targets? targetsFor(UserProfile p, double? latestWeightKg, DateTime now) {
  if (missingForTargets(p, latestWeightKg).isNotEmpty) return null;
  return computeTargets(
    sex: p.sex!,
    weightKg: latestWeightKg!,
    heightCm: p.heightCm!,
    age: ageOn(p.birthYear!, now),
    activity: p.activityLevel!,
    goal: p.weightGoal!,
  );
}
