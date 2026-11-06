import 'package:drift/drift.dart';

import 'app_database.dart';

/// Built-in exercise library inserted on first launch.
List<ExercisesCompanion> seedExercises() {
  ExercisesCompanion e(
    String name,
    MuscleGroup primary,
    Equipment equipment, {
    List<MuscleGroup> secondary = const [],
    TrackingType tracking = TrackingType.weightReps,
  }) {
    return ExercisesCompanion.insert(
      name: name,
      primaryMuscle: primary,
      equipment: equipment,
      trackingType: tracking,
      secondaryMuscles: Value(secondary.map((m) => m.name).join(',')),
    );
  }

  const chest = MuscleGroup.chest,
      back = MuscleGroup.back,
      shoulders = MuscleGroup.shoulders,
      biceps = MuscleGroup.biceps,
      triceps = MuscleGroup.triceps,
      forearms = MuscleGroup.forearms,
      quads = MuscleGroup.quadriceps,
      hams = MuscleGroup.hamstrings,
      glutes = MuscleGroup.glutes,
      calves = MuscleGroup.calves,
      abs = MuscleGroup.abs,
      core = MuscleGroup.core;

  const bb = Equipment.barbell,
      db = Equipment.dumbbell,
      cable = Equipment.cable,
      machine = Equipment.machine,
      bw = Equipment.bodyweight;

  return [
    // Chest
    e('Barbell Bench Press', chest, bb, secondary: [triceps, shoulders]),
    e(
      'Incline Barbell Bench Press',
      chest,
      bb,
      secondary: [shoulders, triceps],
    ),
    e('Dumbbell Bench Press', chest, db, secondary: [triceps, shoulders]),
    e('Incline Dumbbell Press', chest, db, secondary: [shoulders, triceps]),
    e('Dumbbell Fly', chest, db),
    e('Cable Crossover', chest, cable),
    e('Machine Chest Press', chest, machine, secondary: [triceps]),
    e('Pec Deck', chest, machine),
    e(
      'Push-up',
      chest,
      bw,
      secondary: [triceps, shoulders],
      tracking: TrackingType.bodyweightReps,
    ),
    e(
      'Chest Dip',
      chest,
      bw,
      secondary: [triceps],
      tracking: TrackingType.bodyweightReps,
    ),

    // Back
    e('Deadlift', back, bb, secondary: [hams, glutes, forearms]),
    e('Barbell Row', back, bb, secondary: [biceps]),
    e('Dumbbell Row', back, db, secondary: [biceps]),
    e(
      'Pull-up',
      back,
      bw,
      secondary: [biceps],
      tracking: TrackingType.bodyweightReps,
    ),
    e(
      'Chin-up',
      back,
      bw,
      secondary: [biceps],
      tracking: TrackingType.bodyweightReps,
    ),
    e(
      'Assisted Pull-up',
      back,
      machine,
      secondary: [biceps],
      tracking: TrackingType.assistedBodyweight,
    ),
    e('Lat Pulldown', back, cable, secondary: [biceps]),
    e('Seated Cable Row', back, cable, secondary: [biceps]),
    e('T-Bar Row', back, bb, secondary: [biceps]),
    e('Straight-Arm Pulldown', back, cable),

    // Shoulders
    e('Overhead Press', shoulders, bb, secondary: [triceps]),
    e('Seated Dumbbell Shoulder Press', shoulders, db, secondary: [triceps]),
    e('Lateral Raise', shoulders, db),
    e('Cable Lateral Raise', shoulders, cable),
    e('Rear Delt Fly', shoulders, db, secondary: [back]),
    e('Face Pull', shoulders, cable, secondary: [back]),

    // Arms
    e('Barbell Curl', biceps, bb, secondary: [forearms]),
    e('Dumbbell Curl', biceps, db, secondary: [forearms]),
    e('Hammer Curl', biceps, db, secondary: [forearms]),
    e('Preacher Curl', biceps, machine),
    e('Cable Curl', biceps, cable),
    e('Tricep Pushdown', triceps, cable),
    e('Overhead Cable Extension', triceps, cable),
    e('Skull Crusher', triceps, bb),
    e('Close-Grip Bench Press', triceps, bb, secondary: [chest]),
    e('Wrist Curl', forearms, db),

    // Legs
    e('Back Squat', quads, bb, secondary: [glutes, hams]),
    e('Front Squat', quads, bb, secondary: [glutes, core]),
    e('Leg Press', quads, machine, secondary: [glutes]),
    e('Bulgarian Split Squat', quads, db, secondary: [glutes]),
    e('Leg Extension', quads, machine),
    e('Romanian Deadlift', hams, bb, secondary: [glutes, back]),
    e('Lying Leg Curl', hams, machine),
    e('Seated Leg Curl', hams, machine),
    e('Hip Thrust', glutes, bb, secondary: [hams]),
    e('Walking Lunge', glutes, db, secondary: [quads]),
    e('Standing Calf Raise', calves, machine),
    e('Seated Calf Raise', calves, machine),

    // Core
    e('Hanging Leg Raise', abs, bw, tracking: TrackingType.bodyweightReps),
    e('Cable Crunch', abs, cable),
    e('Plank', core, bw, tracking: TrackingType.duration),
    e(
      'Ab Wheel Rollout',
      core,
      Equipment.other,
      tracking: TrackingType.bodyweightReps,
    ),

    // Resistance bands (added in schema v2; also inserted on upgrade)
    ...bandSeedExercises(),
  ];
}

/// Band versions of common cable and free-weight movements.
List<ExercisesCompanion> bandSeedExercises() {
  ExercisesCompanion b(
    String name,
    MuscleGroup primary, [
    List<MuscleGroup> secondary = const [],
  ]) {
    return ExercisesCompanion.insert(
      name: name,
      primaryMuscle: primary,
      equipment: Equipment.band,
      trackingType: TrackingType.bandReps,
      secondaryMuscles: Value(secondary.map((m) => m.name).join(',')),
    );
  }

  return [
    b('Band Chest Press', MuscleGroup.chest, [
      MuscleGroup.triceps,
      MuscleGroup.shoulders,
    ]),
    b('Band Chest Fly', MuscleGroup.chest),
    b('Band Row', MuscleGroup.back, [MuscleGroup.biceps]),
    b('Band Lat Pulldown', MuscleGroup.back, [MuscleGroup.biceps]),
    b('Band Pull-Apart', MuscleGroup.shoulders, [MuscleGroup.back]),
    b('Band Face Pull', MuscleGroup.shoulders, [MuscleGroup.back]),
    b('Band Lateral Raise', MuscleGroup.shoulders),
    b('Band Overhead Press', MuscleGroup.shoulders, [MuscleGroup.triceps]),
    b('Band Bicep Curl', MuscleGroup.biceps, [MuscleGroup.forearms]),
    b('Band Tricep Pushdown', MuscleGroup.triceps),
    b('Band Squat', MuscleGroup.quadriceps, [MuscleGroup.glutes]),
    b('Band Good Morning', MuscleGroup.hamstrings, [
      MuscleGroup.glutes,
      MuscleGroup.back,
    ]),
    b('Banded Glute Bridge', MuscleGroup.glutes, [MuscleGroup.hamstrings]),
    b('Band Glute Kickback', MuscleGroup.glutes),
    b('Band Pallof Press', MuscleGroup.core, [MuscleGroup.abs]),
    b('Band Woodchop', MuscleGroup.core, [MuscleGroup.abs]),
  ];
}
