import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/app/theme/muscle_style.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/dashboard/data/week_summary.dart';
import 'package:lock_in/features/dashboard/presentation/home_screen.dart';
import 'package:lock_in/features/dashboard/presentation/weekly_activity_card.dart';
import 'package:lock_in/features/workout/data/workout_repository.dart';

void main() {
  final thursday = DateTime(2026, 11, 5, 19); // week of Mon 2 Nov
  final t = DateTime(2026, 1, 1);

  Exercise ex(String name, MuscleGroup muscle, {TrackingType? tracking}) =>
      Exercise(
        id: name.hashCode,
        name: name,
        primaryMuscle: muscle,
        secondaryMuscles: '',
        equipment: Equipment.barbell,
        trackingType: tracking ?? TrackingType.weightReps,
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

  var nextId = 1;
  WorkoutDetail workout(
    DateTime at,
    int minutes,
    List<WorkoutExerciseDetail> e,
  ) => WorkoutDetail(
    Workout(
      id: nextId++,
      name: 'W',
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

  final bench = ex('Bench Press', MuscleGroup.chest);
  final squat = ex('Squat', MuscleGroup.quadriceps);
  final row = ex('Row', MuscleGroup.back);

  WeekSummary sample() => computeWeekSummary(
    now: thursday,
    workouts: [
      // Last week: Tue (before "last Thursday 19:00") and Sat (after).
      workout(DateTime(2026, 10, 27, 18), 50, [
        item(bench, [set(100, 5), set(100, 5)]),
      ]),
      workout(DateTime(2026, 10, 31, 10), 40, [
        item(row, [set(60, 10)]),
      ]),
      // This week: Mon push, Wed legs.
      workout(DateTime(2026, 11, 2, 18), 48, [
        item(bench, [
          set(60, 10, type: SetType.warmup), // not counted
          set(100, 5), // e1RM 116.7
          set(100, 5),
        ]),
        item(row, [set(60, 10)]),
      ]),
      workout(DateTime(2026, 11, 4, 18), 56, [
        item(squat, [set(120, 5), set(120, 5), set(120, 5)]),
      ]),
      // Two weeks ago: ignored.
      workout(DateTime(2026, 10, 20, 18), 90, [
        item(squat, [set(200, 1)]),
      ]),
    ],
  );

  test('this week totals exclude warm-ups and older weeks', () {
    final s = sample();
    expect(s.weekStart, DateTime(2026, 11, 2));
    expect(s.thisWeek.workouts, 2);
    expect(s.thisWeek.minutes, 104);
    expect(s.thisWeek.sets, 6);
    expect(s.thisWeek.volumeKg, 100 * 5 * 2 + 60 * 10 + 120 * 5 * 3);
    expect(s.topLift?.exercise, 'Squat');
    expect(s.topLift!.e1rmKg, closeTo(140, 0.01)); // 120 × 5
  });

  test('last week is compared up to the same moment', () {
    final s = sample();
    expect(s.lastWeekSoFar.workouts, 1, reason: 'Saturday is still ahead');
    expect(s.lastWeekSoFar.minutes, 50);
    expect(s.lastWeekSoFar.sets, 2);
    expect(s.lastWeekTotal, 2);
    expect(s.volumeChange, closeTo((3400 - 1000) / 1000, 1e-9));
  });

  test('days carry minutes, workouts and main region', () {
    final s = sample();
    expect(s.days, hasLength(7));
    expect(s.days[0].minutes, 48);
    expect(dominantRegion(s.days[0].muscleSets), MuscleRegion.push);
    expect(s.days[1].trained, isFalse);
    expect(dominantRegion(s.days[2].muscleSets), MuscleRegion.legs);
    expect(s.days[3].trained, isFalse);
  });

  test('dominant region: most sets wins, ties go to the earlier region', () {
    expect(dominantRegion({}), isNull);
    expect(
      dominantRegion({
        MuscleGroup.back: 3,
        MuscleGroup.biceps: 2,
        MuscleGroup.chest: 4,
      }),
      MuscleRegion.pull,
    );
    expect(
      dominantRegion({MuscleGroup.abs: 2, MuscleGroup.calves: 2}),
      MuscleRegion.legs,
    );
  });

  group('pace (goal 3)', () {
    WeekPace pace(int workouts, int weekday) => weekPace(
      workouts: workouts,
      goal: 3,
      now: DateTime(2026, 11, 1 + weekday, 12), // 2 Nov is a Monday
    );

    test('Monday with nothing logged is a new week', () {
      final p = pace(0, 1);
      expect(p.state, WeekPaceState.newWeek);
      expect(p.toGo, 3);
      expect(p.daysLeft, 7);
    });

    test('Thursday with 2 is on track', () {
      final p = pace(2, 4);
      expect(p.state, WeekPaceState.onTrack);
      expect(p.toGo, 1);
      expect(p.daysLeft, 4);
    });

    test('Friday with 1 is one behind', () {
      final p = pace(1, 5);
      expect(p.state, WeekPaceState.behind);
      expect(p.behindBy, 1);
      expect(p.toGo, 2);
    });

    test('reaching the goal any day is goal hit', () {
      expect(pace(3, 3).state, WeekPaceState.goalHit);
      expect(pace(4, 7).toGo, 0);
    });

    test('Sunday counts as the last day', () {
      expect(pace(2, 7).daysLeft, 1);
      expect(pace(2, 7).state, WeekPaceState.behind);
    });
  });

  group('streak', () {
    final now = DateTime(2026, 11, 5, 12);
    List<DateTime> weekOf(DateTime monday, int n) => [
      for (var i = 0; i < n; i++) monday.add(Duration(days: i, hours: 18)),
    ];

    test('counts back from last week until a miss', () {
      final starts = [
        ...weekOf(DateTime(2026, 10, 26), 3),
        ...weekOf(DateTime(2026, 10, 19), 4),
        ...weekOf(DateTime(2026, 10, 12), 2), // miss
        ...weekOf(DateTime(2026, 10, 5), 3),
      ];
      expect(weekStreak(workoutStarts: starts, goal: 3, now: now), 2);
    });

    test('this week joins once its goal is hit', () {
      final starts = [
        ...weekOf(DateTime(2026, 11, 2), 3),
        ...weekOf(DateTime(2026, 10, 26), 3),
      ];
      expect(weekStreak(workoutStarts: starts, goal: 3, now: now), 2);
    });

    test('an unfinished week does not break it', () {
      final starts = [
        ...weekOf(DateTime(2026, 11, 2), 1),
        ...weekOf(DateTime(2026, 10, 26), 3),
      ];
      expect(weekStreak(workoutStarts: starts, goal: 3, now: now), 1);
      expect(weekStreak(workoutStarts: [], goal: 3, now: now), 0);
    });

    test('works across the October clock change', () {
      // Europe moves clocks back on 25 Oct 2026; weeks must not be skipped.
      final starts = [
        ...weekOf(DateTime(2026, 10, 26), 3),
        ...weekOf(DateTime(2026, 10, 19), 3),
        ...weekOf(DateTime(2026, 10, 12), 3),
      ];
      expect(weekStreak(workoutStarts: starts, goal: 3, now: now), 3);
    });
  });

  test('week range label', () {
    expect(weekRangeLabel(DateTime(2026, 11, 2)), '2–8 Nov');
    expect(weekRangeLabel(DateTime(2026, 11, 30)), '30 Nov – 6 Dec');
  });

  group('card', () {
    Future<void> pump(
      WidgetTester tester,
      WeekSummary s, {
      double textScale = 1,
      int streak = 0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 900),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: WeeklyActivityCard(
                  summary: s,
                  unit: WeightUnit.kg,
                  streak: streak,
                  onEditGoals: () {},
                  onOpenWorkout: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows pace, deltas, regions and highlights', (tester) async {
      await pump(tester, sample(), streak: 6);
      expect(find.text('On track'), findsOneWidget);
      expect(find.text('1 more to hit 3 · 4 days left'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
      expect(find.text('48m'), findsOneWidget);
      expect(find.textContaining('up 1 on last week'), findsOneWidget);
      expect(
        find.textContaining('up 240% on last week'),
        findsOneWidget,
      ); // volume
      expect(find.textContaining('Squat e1RM'), findsOneWidget);
      expect(find.textContaining('3,400'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty Monday reads as a new week', (tester) async {
      await pump(tester, WeekSummary.empty(DateTime(2026, 11, 2, 8)));
      expect(find.text('New week'), findsOneWidget);
      expect(find.text('3 to go · 7 days left'), findsOneWidget);
      expect(find.text('no lifts yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits at large text scale', (tester) async {
      await pump(tester, sample(), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('48m'), findsNothing, reason: 'minutes hidden');
    });
  });
}
