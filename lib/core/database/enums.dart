// Enums persisted as their `.name` via Drift's `textEnum`.
// Renaming a value is a breaking change — add a migration if you ever do.

enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  shoulders('Shoulders'),
  biceps('Biceps'),
  triceps('Triceps'),
  forearms('Forearms'),
  quadriceps('Quads'),
  hamstrings('Hamstrings'),
  glutes('Glutes'),
  calves('Calves'),
  abs('Abs'),
  core('Core');

  const MuscleGroup(this.label);
  final String label;
}

enum Equipment {
  dumbbell('Dumbbells'),
  barbell('Barbell'),
  cable('Cable'),
  machine('Machine'),
  bodyweight('Bodyweight'),
  band('Resistance band'),
  other('Other');

  const Equipment(this.label);
  final String label;
}

/// Decides which inputs a set row shows and how volume is calculated.
enum TrackingType {
  weightReps('Weight × reps'),
  bodyweightReps('Bodyweight reps'),
  assistedBodyweight('Assisted bodyweight'),
  duration('Duration'),

  /// Resistance band: each set records the band used and the reps.
  /// Bands have no reliable kg value, so they're left out of volume.
  bandReps('Band × reps');

  const TrackingType(this.label);
  final String label;
}

/// Resistance band strength, lightest first. Colours differ by brand,
/// so the app names levels rather than colours.
enum BandLevel {
  extraLight('Extra light'),
  light('Light'),
  medium('Medium'),
  heavy('Heavy'),
  extraHeavy('Extra heavy');

  const BandLevel(this.label);
  final String label;

  /// Short label for compact set rows.
  String get short => switch (this) {
    BandLevel.extraLight => 'XL',
    BandLevel.light => 'L',
    BandLevel.medium => 'M',
    BandLevel.heavy => 'H',
    BandLevel.extraHeavy => 'XH',
  };
}

enum SetType {
  warmup('Warm-up'),
  normal('Working'),
  drop('Drop set'),
  failure('To failure');

  const SetType(this.label);
  final String label;

  /// Warm-ups never count toward PRs or volume.
  bool get countsTowardStats => this != SetType.warmup;
}

enum WorkoutStatus { active, completed, discarded }

/// Meal slot for a food entry (schema v3).
enum Meal {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snacks');

  const Meal(this.label);
  final String label;

  /// Sensible default for "now": breakfast before 11, lunch before 16,
  /// dinner before 21, otherwise a snack.
  static Meal forTime(DateTime t) => t.hour < 11
      ? Meal.breakfast
      : t.hour < 16
      ? Meal.lunch
      : t.hour < 21
      ? Meal.dinner
      : Meal.snack;
}

enum MeasurementType {
  bodyWeight('Body weight', isLength: false),
  bodyFat('Body fat', isLength: false),
  waist('Waist'),
  chest('Chest'),
  leftArm('Left arm'),
  rightArm('Right arm'),
  leftThigh('Left thigh'),
  rightThigh('Right thigh'),
  hips('Hips');

  const MeasurementType(this.label, {this.isLength = true});
  final String label;
  final bool isLength;
}

enum WeightUnit { kg, lb }

/// For the calorie estimate (Mifflin-St Jeor needs it). Schema v5.
enum Sex {
  male('Male'),
  female('Female');

  const Sex(this.label);
  final String label;
}

/// Daily activity outside the gym, as a TDEE multiplier. Schema v5.
enum ActivityLevel {
  sedentary('Mostly sitting', 'Desk job, little walking', 1.2),
  light(
    'Lightly active',
    'On your feet some of the day, or 1–3 workouts a week',
    1.375,
  ),
  moderate('Moderately active', '3–5 workouts a week, or an active job', 1.55),
  active('Very active', '6–7 hard workouts a week', 1.725),
  athlete('Athlete', 'Twice-a-day training or a physical job', 1.9);

  const ActivityLevel(this.label, this.hint, this.multiplier);
  final String label;
  final String hint;
  final double multiplier;
}

/// What the calorie target aims for. Schema v5.
enum WeightGoal {
  lose('Lose fat', -0.20, 2.0),
  maintain('Maintain', 0, 1.8),
  gain('Build muscle', 0.10, 1.8);

  const WeightGoal(this.label, this.kcalAdjust, this.proteinPerKg);
  final String label;

  /// Fraction added to maintenance calories.
  final double kcalAdjust;

  /// Protein target in grams per kg of body weight.
  final double proteinPerKg;
}

enum LengthUnit { cm, inch }
