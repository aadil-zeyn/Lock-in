import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/share/data/share_stats.dart';
import 'package:lock_in/features/workout/data/workout_repository.dart';

void main() {
  final now = DateTime(2026, 11, 6, 20); // Friday
  final t = DateTime(2026, 1, 1);

  Exercise ex(String name, TrackingType tracking) => Exercise(
    id: name.hashCode,
    name: name,
    primaryMuscle: MuscleGroup.chest,
    secondaryMuscles: '',
    equipment: Equipment.barbell,
    trackingType: tracking,
    isCustom: false,
    createdAt: t,
    updatedAt: t,
  );

  WorkoutSet set(double? kg, int? reps, {SetType type = SetType.normal}) =>
      WorkoutSet(
        id: 0,
        workoutExerciseId: 0,
        setNumber: 1,
        setType: type,
        weightKg: kg,
        reps: reps,
        isCompleted: true,
        createdAt: t,
        updatedAt: t,
      );

  WorkoutDetail workout(
    DateTime at,
    int minutes,
    List<WorkoutExerciseDetail> e,
  ) => WorkoutDetail(
    Workout(
      id: at.day,
      name: 'W${at.day}',
      status: WorkoutStatus.completed,
      startedAt: at,
      durationSeconds: minutes * 60,
      createdAt: at,
      updatedAt: at,
    ),
    e,
  );

  WorkoutExerciseDetail item(Exercise e, List<WorkoutSet> sets) =>
      WorkoutExerciseDetail(
        entry: WorkoutExercise(
          id: 0,
          workoutId: 0,
          exerciseId: e.id,
          exerciseNameSnapshot: e.name,
          position: 0,
        ),
        exercise: e,
        sets: sets,
      );

  test('week numbers, top lift, average kcal and 30-day weight change', () {
    final bench = ex('Bench Press', TrackingType.weightReps);
    final plank = ex('Plank', TrackingType.duration);
    final s = computeWeekShare(
      now: now,
      workouts: [
        workout(DateTime(2026, 11, 3, 18), 60, [
          item(bench, [
            set(150, 1, type: SetType.warmup), // ignored
            set(100, 5), // e1RM 116.7
          ]),
          item(plank, [set(null, null)]),
        ]),
        workout(DateTime(2026, 11, 5, 18), 45, [
          item(bench, [set(105, 3)]), // e1RM 115.5
        ]),
        workout(DateTime(2026, 10, 30, 18), 50, []), // last week: ignored
      ],
      weightsNewestFirst: [
        BodyMeasurement(
          id: 1,
          measurementType: MeasurementType.bodyWeight,
          measuredValue: 78.2,
          recordedAt: DateTime(2026, 11, 6),
          createdAt: t,
          updatedAt: t,
        ),
        BodyMeasurement(
          id: 2,
          measurementType: MeasurementType.bodyWeight,
          measuredValue: 79.0,
          recordedAt: DateTime(2026, 10, 20),
          createdAt: t,
          updatedAt: t,
        ),
        BodyMeasurement(
          id: 3,
          measurementType: MeasurementType.bodyWeight,
          measuredValue: 85.0,
          recordedAt: DateTime(2026, 8, 1),
          createdAt: t,
          updatedAt: t,
        ),
      ],
      foodThisWeek: [
        FoodEntry(
          id: 1,
          loggedAt: DateTime(2026, 11, 3, 9),
          meal: Meal.breakfast,
          name: '',
          kcal: 1000,
          createdAt: t,
          updatedAt: t,
        ),
        FoodEntry(
          id: 2,
          loggedAt: DateTime(2026, 11, 3, 20),
          meal: Meal.dinner,
          name: '',
          kcal: 1200,
          createdAt: t,
          updatedAt: t,
        ),
        FoodEntry(
          id: 3,
          loggedAt: DateTime(2026, 11, 4, 13),
          meal: Meal.lunch,
          name: '',
          kcal: 1800,
          createdAt: t,
          updatedAt: t,
        ),
      ],
    );
    expect(s.weekStart, DateTime(2026, 11, 2));
    expect(s.workouts, 2);
    expect(s.minutes, 105);
    expect(s.trainedDays, [false, true, false, true, false, false, false]);
    expect(s.topLift!.exercise, 'Bench Press');
    expect(s.topLift!.e1rmKg, closeTo(116.67, 0.01));
    expect(s.volumeKg, 500 + 315, reason: 'warm-up and plank excluded');
    expect(s.avgKcal, 2000);
    expect(s.weightChangeKg, closeTo(-0.8, 0.001));
  });

  test('empty week', () {
    final s = computeWeekShare(
      now: now,
      workouts: const [],
      weightsNewestFirst: const [],
      foodThisWeek: const [],
    );
    expect(
      (s.workouts, s.sets, s.topLift, s.avgKcal, s.weightChangeKg),
      (0, 0, null, null, null),
    );
  });
}
