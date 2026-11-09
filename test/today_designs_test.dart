import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/features/share/data/day_card.dart';
import 'package:lock_in/features/share/presentation/share_backgrounds.dart';
import 'package:lock_in/features/share/presentation/story_cards.dart';
import 'package:lock_in/features/share/presentation/today_designs.dart';

DayCardData _day({
  String? workout,
  int? steps = 8432,
  List<int>? week = const [11200, 6400, 10350, 12800, 9100, 10020, 8432],
}) => DayCardData(
  date: DateTime(2026, 11, 9, 19),
  steps: steps,
  stepsGoal: 10000,
  streak: 12,
  workoutName: workout,
  proteinG: 142,
  proteinGoal: 140,
  kcal: 2310,
  kcalGoal: 2400,
  kcalOk: true,
  exercises: workout == null
      ? const []
      : const [
          (name: 'Barbell Bench Press', summary: '4 × 6–8 · 80 kg'),
          (name: 'Incline Dumbbell Press', summary: '3 × 10 · 30 kg'),
          (name: 'Dumbbell Shoulder Press', summary: '3 × 10 · 24 kg'),
          (name: 'Cable Crossover', summary: '3 × 12 · 15 kg'),
          (name: 'Triceps Pushdown', summary: '3 × 12 · 30 kg'),
          (name: 'Lateral Raise', summary: '3 × 15 · 10 kg'),
        ],
  workoutMinutes: workout == null ? null : 64,
  workoutSets: workout == null ? 0 : 19,
  stepsWeek: week,
  heightCm: 178,
);

void main() {
  test('distance estimate uses height when known', () {
    expect(estimateDistanceKm(10000, null), closeTo(7.6, 0.01));
    expect(estimateDistanceKm(10000, 180), closeTo(7.47, 0.01));
  });

  test('backgrounds: matching kind first, suggestion rotates by day', () {
    final gym = backgroundsFor(workoutDay: true);
    expect(gym.first.kind, ShareBgKind.gym);
    expect(gym.length, shareBackgrounds.length);
    expect(backgroundsFor(workoutDay: false).first.kind, ShareBgKind.steps);
    final a = suggestedBackground(workoutDay: false, dayOfYear: 10);
    final b = suggestedBackground(workoutDay: false, dayOfYear: 11);
    expect(a.kind, ShareBgKind.steps);
    expect(a.id, isNot(b.id));
    expect(
      suggestedBackground(workoutDay: true, dayOfYear: 10).kind,
      ShareBgKind.gym,
    );
  });

  test('design ids are unique', () {
    final ids = todayDesigns.map((t) => t.id).toSet();
    expect(ids.length, todayDesigns.length);
  });

  // Layout overflows throw in widget tests, so this catches a design that
  // doesn't fit a long workout, a rest day, or missing steps. The test font
  // is taller than Roboto; the older Year poster only fits with Roboto, so
  // it's left out here.
  for (final t in todayDesigns.where((t) => t.id != 'year')) {
    testWidgets('${t.name} design lays out on any day', (tester) async {
      for (final d in [
        _day(workout: 'Push Day — heavy upper body and arms'),
        _day(),
        _day(workout: 'Legs', steps: null, week: null),
        _day(steps: 123456),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: SizedBox.fromSize(
                  size: storySize,
                  child: t.builder(d, null),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
