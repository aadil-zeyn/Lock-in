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
  duration('Duration');

  const TrackingType(this.label);
  final String label;
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

enum LengthUnit { cm, inch }
