import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/strength.dart';

/// One plotted value.
typedef ChartPoint = ({DateTime x, double y});

enum ChartRange {
  month('1M', 30),
  quarter('3M', 91),
  half('6M', 182),
  year('1Y', 365),
  all('All', null);

  const ChartRange(this.label, this.days);
  final String label;
  final int? days;

  DateTime? since(DateTime now) =>
      days == null ? null : now.subtract(Duration(days: days!));
}

/// Points on or after [since] (all when null), oldest first.
List<ChartPoint> inRange(List<ChartPoint> points, DateTime? since) => [
  for (final p in points)
    if (since == null || !p.x.isBefore(since)) p,
];

/// Trailing average over [window] ending at each point. Smooths day-to-day
/// water-weight noise so the trend is readable. Input must be oldest first.
List<ChartPoint> movingAverage(
  List<ChartPoint> points, {
  Duration window = const Duration(days: 7),
}) {
  final out = <ChartPoint>[];
  var start = 0;
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    sum += points[i].y;
    while (points[i].x.difference(points[start].x) >= window) {
      sum -= points[start].y;
      start++;
    }
    out.add((x: points[i].x, y: sum / (i - start + 1)));
  }
  return out;
}

class RangeSummary {
  const RangeSummary({
    required this.latest,
    required this.change,
    required this.min,
    required this.max,
    required this.count,
  });
  final double latest;

  /// Latest minus the first value in the range.
  final double change;
  final double min;
  final double max;
  final int count;
}

RangeSummary? summarize(List<ChartPoint> points) {
  if (points.isEmpty) return null;
  var min = points.first.y, max = points.first.y;
  for (final p in points) {
    if (p.y < min) min = p.y;
    if (p.y > max) max = p.y;
  }
  return RangeSummary(
    latest: points.last.y,
    change: points.last.y - points.first.y,
    min: min,
    max: max,
    count: points.length,
  );
}

typedef WeekTraining = ({DateTime weekStart, int workouts, int minutes});

/// Completed workouts per week for the last [weeks] weeks, oldest first;
/// the current week is last. Empty weeks are included as zeros.
List<WeekTraining> weeklyTraining(
  List<Workout> completed,
  DateTime now, {
  int weeks = 8,
}) {
  final thisWeek = startOfWeek(now);
  final starts = [
    for (var i = weeks - 1; i >= 0; i--)
      thisWeek.subtract(Duration(days: 7 * i)),
  ];
  final count = {for (final s in starts) s: 0};
  final minutes = {for (final s in starts) s: 0};
  for (final w in completed) {
    if (w.status != WorkoutStatus.completed) continue;
    final s = startOfWeek(w.startedAt);
    if (!count.containsKey(s)) continue;
    count[s] = count[s]! + 1;
    minutes[s] = minutes[s]! + (w.durationSeconds ?? 0) ~/ 60;
  }
  return [
    for (final s in starts)
      (weekStart: s, workouts: count[s]!, minutes: minutes[s]!),
  ];
}

/// What the strength chart measures for an exercise.
enum ProgressMetric {
  e1rm('Best estimated 1RM', 'kg'),
  topWeight('Heaviest set', 'kg'),
  reps('Most reps in a set', 'reps'),
  seconds('Longest hold', 's');

  const ProgressMetric(this.label, this.unit);
  final String label;
  final String unit;
}

ProgressMetric metricFor(TrackingType t) => switch (t) {
  TrackingType.weightReps => ProgressMetric.e1rm,
  TrackingType.duration => ProgressMetric.seconds,
  TrackingType.bodyweightReps ||
  TrackingType.assistedBodyweight ||
  TrackingType.bandReps => ProgressMetric.reps,
};

/// A logged set with the date of its workout.
typedef DatedSet = ({
  DateTime date,
  int workoutId,
  SetType type,
  double? weightKg,
  int? reps,
  int? seconds,
});

/// One point per workout: the best value of [metric] among completed
/// working sets (warm-ups never count, PRD v1.1 §2). For e1RM, sets
/// outside 1–12 reps fall back to the heaviest set if nothing qualifies.
List<ChartPoint> exerciseProgress(List<DatedSet> sets, ProgressMetric metric) {
  final byWorkout = <int, List<DatedSet>>{};
  for (final s in sets) {
    if (!s.type.countsTowardStats) continue;
    byWorkout.putIfAbsent(s.workoutId, () => []).add(s);
  }
  final out = <ChartPoint>[];
  for (final group in byWorkout.values) {
    double? best;
    for (final s in group) {
      final v = switch (metric) {
        ProgressMetric.e1rm =>
          (s.weightKg != null && s.reps != null)
              ? estimateOneRepMax(s.weightKg!, s.reps!)
              : null,
        ProgressMetric.topWeight => (s.weightKg ?? 0) > 0 ? s.weightKg : null,
        ProgressMetric.reps => s.reps?.toDouble(),
        ProgressMetric.seconds => s.seconds?.toDouble(),
      };
      if (v != null && (best == null || v > best)) best = v;
    }
    if (best == null && metric == ProgressMetric.e1rm) {
      for (final s in group) {
        final w = s.weightKg;
        if (w != null && w > 0 && (best == null || w > best)) best = w;
      }
    }
    if (best != null) out.add((x: group.first.date, y: best));
  }
  out.sort((a, b) => a.x.compareTo(b.x));
  return out;
}
