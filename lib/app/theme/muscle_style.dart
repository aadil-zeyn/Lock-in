import 'package:flutter/material.dart';

import '../../core/database/enums.dart';
import 'app_tokens.dart';

/// UI-only styling for database enums. Kept out of `enums.dart` so the
/// database layer has no Flutter dependency.

enum MuscleRegion {
  push('Push', AppColors.push),
  pull('Pull', AppColors.pull),
  legs('Legs', AppColors.legs),
  core('Core', AppColors.core);

  const MuscleRegion(this.label, this.color);
  final String label;
  final Color color;
}

extension MuscleGroupStyle on MuscleGroup {
  MuscleRegion get region => switch (this) {
    MuscleGroup.chest ||
    MuscleGroup.shoulders ||
    MuscleGroup.triceps => MuscleRegion.push,
    MuscleGroup.back ||
    MuscleGroup.biceps ||
    MuscleGroup.forearms => MuscleRegion.pull,
    MuscleGroup.quadriceps ||
    MuscleGroup.hamstrings ||
    MuscleGroup.glutes ||
    MuscleGroup.calves => MuscleRegion.legs,
    MuscleGroup.abs || MuscleGroup.core => MuscleRegion.core,
  };

  Color get color => region.color;

  /// Two-letter badge text, e.g. "CH", "QU".
  String get initials => label.substring(0, 2).toUpperCase();
}

extension EquipmentStyle on Equipment {
  IconData get icon => switch (this) {
    Equipment.dumbbell => Icons.fitness_center_rounded,
    Equipment.barbell => Icons.linear_scale_rounded,
    Equipment.cable => Icons.cable_rounded,
    Equipment.machine => Icons.precision_manufacturing_outlined,
    Equipment.bodyweight => Icons.accessibility_new_rounded,
    Equipment.band => Icons.gesture_rounded,
    Equipment.other => Icons.category_outlined,
  };
}

extension TrackingTypeStyle on TrackingType {
  IconData get icon => switch (this) {
    TrackingType.weightReps => Icons.fitness_center_rounded,
    TrackingType.bodyweightReps => Icons.accessibility_new_rounded,
    TrackingType.assistedBodyweight => Icons.support_rounded,
    TrackingType.duration => Icons.timer_outlined,
    TrackingType.bandReps => Icons.gesture_rounded,
  };

  /// One-line explanation shown in the create form.
  String get hint => switch (this) {
    TrackingType.weightReps => 'Log weight and reps, e.g. bench press',
    TrackingType.bodyweightReps =>
      'Reps with your body weight, optional added weight',
    TrackingType.assistedBodyweight => 'Reps with machine or band assistance',
    TrackingType.duration => 'Log time held, e.g. plank',
    TrackingType.bandReps => 'Pick the band (light → extra heavy) and reps',
  };
}

extension BandLevelStyle on BandLevel {
  /// Lighter bands read lighter; the label always goes with it.
  Color get color => switch (this) {
    BandLevel.extraLight => const Color(0xFF9FE7C4),
    BandLevel.light => AppColors.sets,
    BandLevel.medium => AppColors.volume,
    BandLevel.heavy => AppColors.time,
    BandLevel.extraHeavy => AppColors.streak,
  };
}
