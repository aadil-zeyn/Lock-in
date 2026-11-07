/// Photos for the built-in exercises, bundled as two WebP frames each
/// (start and end position) in `assets/exercises/`.
///
/// Source: Free Exercise DB (github.com/yuhonas/free-exercise-db),
/// released into the public domain under the Unlicense. Resized to 400 px
/// wide. Custom exercises and the few built-ins without a good match fall
/// back to the [MuscleMap] diagram.
library;

/// Built-in exercise name → asset base name. Built-ins can't be renamed,
/// so the name is a stable key.
const exercisePhotoBases = <String, String>{
  'Barbell Bench Press': 'barbell_bench_press_medium_grip',
  'Incline Barbell Bench Press': 'barbell_incline_bench_press_medium_grip',
  'Dumbbell Bench Press': 'dumbbell_bench_press',
  'Incline Dumbbell Press': 'incline_dumbbell_press',
  'Dumbbell Fly': 'dumbbell_flyes',
  'Cable Crossover': 'cable_crossover',
  'Machine Chest Press': 'machine_bench_press',
  'Pec Deck': 'butterfly',
  'Push-up': 'pushups',
  'Chest Dip': 'dips_chest_version',
  'Deadlift': 'barbell_deadlift',
  'Barbell Row': 'bent_over_barbell_row',
  'Dumbbell Row': 'one_arm_dumbbell_row',
  'Pull-up': 'pullups',
  'Chin-up': 'chin_up',
  'Assisted Pull-up': 'band_assisted_pull_up',
  'Lat Pulldown': 'wide_grip_lat_pulldown',
  'Seated Cable Row': 'seated_cable_rows',
  'T-Bar Row': 't_bar_row_with_handle',
  'Straight-Arm Pulldown': 'straight_arm_pulldown',
  'Overhead Press': 'standing_military_press',
  'Seated Dumbbell Shoulder Press': 'dumbbell_shoulder_press',
  'Lateral Raise': 'side_lateral_raise',
  'Cable Lateral Raise': 'cable_seated_lateral_raise',
  'Rear Delt Fly': 'reverse_flyes',
  'Face Pull': 'face_pull',
  'Barbell Curl': 'barbell_curl',
  'Dumbbell Curl': 'dumbbell_bicep_curl',
  'Hammer Curl': 'hammer_curls',
  'Preacher Curl': 'preacher_curl',
  'Cable Curl': 'standing_biceps_cable_curl',
  'Tricep Pushdown': 'triceps_pushdown',
  'Overhead Cable Extension': 'cable_rope_overhead_triceps_extension',
  'Skull Crusher': 'ez_bar_skullcrusher',
  'Close-Grip Bench Press': 'close_grip_barbell_bench_press',
  'Wrist Curl': 'seated_palm_up_barbell_wrist_curl',
  'Back Squat': 'barbell_squat',
  'Front Squat': 'front_barbell_squat',
  'Leg Press': 'leg_press',
  'Bulgarian Split Squat': 'split_squat_with_dumbbells',
  'Leg Extension': 'leg_extensions',
  'Romanian Deadlift': 'romanian_deadlift',
  'Lying Leg Curl': 'lying_leg_curls',
  'Seated Leg Curl': 'seated_leg_curl',
  'Hip Thrust': 'barbell_hip_thrust',
  'Walking Lunge': 'bodyweight_walking_lunge',
  'Standing Calf Raise': 'standing_calf_raises',
  'Seated Calf Raise': 'seated_calf_raise',
  'Hanging Leg Raise': 'hanging_leg_raise',
  'Cable Crunch': 'cable_crunch',
  'Plank': 'plank',
  'Ab Wheel Rollout': 'ab_roller',
  'Band Chest Fly': 'cross_over_with_bands',
  'Band Pull-Apart': 'band_pull_apart',
  'Band Lateral Raise': 'lateral_raise_with_bands',
  'Band Overhead Press': 'shoulder_press_with_bands',
  'Band Squat': 'squats_with_bands',
  'Band Good Morning': 'band_good_morning',
  'Banded Glute Bridge': 'hip_lift_with_band',
  'Band Glute Kickback': 'glute_kickback',
  'Band Pallof Press': 'pallof_press',
  'Band Woodchop': 'standing_cable_wood_chop',
};

/// Asset paths for an exercise's start and end frames, or null.
({String start, String end})? exercisePhotoFrames(
  String name, {
  required bool isCustom,
}) {
  if (isCustom) return null;
  final base = exercisePhotoBases[name];
  if (base == null) return null;
  return (
    start: 'assets/exercises/${base}_0.webp',
    end: 'assets/exercises/${base}_1.webp',
  );
}
