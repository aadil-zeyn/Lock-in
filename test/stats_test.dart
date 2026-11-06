import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/statistics/data/stats.dart';

void main() {
  final d0 = DateTime(2026, 10, 1, 8);
  ChartPoint p(int day, double y) => (x: d0.add(Duration(days: day)), y: y);

  group('movingAverage', () {
    test('averages the trailing 7 days', () {
      final avg = movingAverage([p(0, 80), p(1, 82), p(2, 81), p(10, 79)]);
      expect(avg.map((e) => e.y), [80, 81, 81, 79]);
    });
    test('empty in, empty out', () => expect(movingAverage([]), isEmpty));
  });

  test('inRange and summarize', () {
    final pts = [p(0, 80), p(20, 78), p(40, 79)];
    final recent = inRange(pts, d0.add(const Duration(days: 15)));
    expect(recent, hasLength(2));
    final s = summarize(recent)!;
    expect(s.latest, 79);
    expect(s.change, 1);
    expect((s.min, s.max, s.count), (78.0, 79.0, 2));
    expect(summarize([]), isNull);
  });

  test('weeklyTraining buckets by Monday and fills empty weeks', () {
    Workout w(DateTime at, int minutes) => Workout(
      id: at.day,
      name: 'W',
      status: WorkoutStatus.completed,
      startedAt: at,
      durationSeconds: minutes * 60,
      createdAt: at,
      updatedAt: at,
    );
    final now = DateTime(2026, 11, 6); // a Friday
    final weeks = weeklyTraining([
      w(DateTime(2026, 11, 3), 60), // this week (Tue)
      w(DateTime(2026, 11, 4), 45),
      w(DateTime(2026, 10, 27), 50), // last week
      w(DateTime(2026, 1, 1), 30), // too old
    ], now);
    expect(weeks, hasLength(8));
    expect(weeks.last.weekStart, DateTime(2026, 11, 2));
    expect(weeks.last.workouts, 2);
    expect(weeks.last.minutes, 105);
    expect(weeks[6].workouts, 1);
    expect(weeks.first.workouts, 0);
  });

  group('exerciseProgress', () {
    DatedSet s(int workout, int day, SetType t, double? kg, int? reps) => (
      date: d0.add(Duration(days: day)),
      workoutId: workout,
      type: t,
      weightKg: kg,
      reps: reps,
      seconds: null,
    );

    test('best e1RM per workout, warm-ups ignored', () {
      final pts = exerciseProgress([
        s(1, 0, SetType.warmup, 200, 1), // would win if counted
        s(1, 0, SetType.normal, 100, 5), // 116.7
        s(1, 0, SetType.normal, 110, 1), // 110
        s(2, 7, SetType.normal, 105, 5), // 122.5
      ], ProgressMetric.e1rm);
      expect(pts.map((e) => e.y.toStringAsFixed(1)), ['116.7', '122.5']);
    });

    test('falls back to heaviest set when reps are out of range', () {
      final pts = exerciseProgress([
        s(1, 0, SetType.normal, 40, 20),
      ], ProgressMetric.e1rm);
      expect(pts.single.y, 40);
    });

    test('rep-based exercises use most reps', () {
      final pts = exerciseProgress([
        s(1, 0, SetType.normal, null, 8),
        s(1, 0, SetType.normal, null, 12),
      ], metricFor(TrackingType.bandReps));
      expect(pts.single.y, 12);
    });
  });
}
