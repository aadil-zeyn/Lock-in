import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/strength.dart';
import '../../workout/data/workout_repository.dart';

/// One day in the Home week strip.
class DayActivity {
  const DayActivity({
    this.minutes = 0,
    this.workoutIds = const [],
    this.muscleSets = const {},
  });

  final int minutes;

  /// Completed workouts that day, newest first.
  final List<int> workoutIds;

  /// Working sets per primary muscle, for the day's main region.
  final Map<MuscleGroup, int> muscleSets;

  bool get trained => workoutIds.isNotEmpty;
}

/// Totals for a stretch of training (this week, or last week so far).
class WeekTotals {
  const WeekTotals({
    this.workouts = 0,
    this.minutes = 0,
    this.sets = 0,
    this.volumeKg = 0,
  });

  final int workouts;
  final int minutes;

  /// Completed working sets (warm-ups excluded).
  final int sets;

  /// kg; weight × reps exercises only, warm-ups excluded.
  final double volumeKg;
}

/// Everything the Home "This week" card shows.
class WeekSummary {
  const WeekSummary({
    required this.weekStart,
    required this.now,
    required this.thisWeek,
    required this.lastWeekSoFar,
    required this.lastWeekTotal,
    required this.days,
    this.topLift,
  });

  /// An empty week (shown while loading).
  factory WeekSummary.empty(DateTime now) => WeekSummary(
    weekStart: startOfWeek(now),
    now: now,
    thisWeek: const WeekTotals(),
    lastWeekSoFar: const WeekTotals(),
    lastWeekTotal: 0,
    days: List.filled(7, const DayActivity()),
  );

  final DateTime weekStart;
  final DateTime now;
  final WeekTotals thisWeek;

  /// Last week from Monday up to the same moment as [now], minus 7 days,
  /// so Thursday is compared with last Thursday rather than a full week.
  final WeekTotals lastWeekSoFar;

  /// Workouts in the whole of last week.
  final int lastWeekTotal;

  /// Monday..Sunday.
  final List<DayActivity> days;

  /// Best estimated 1RM this week.
  final ({String exercise, double e1rmKg})? topLift;

  /// Volume change against [lastWeekSoFar] as a fraction (0.18 = +18%),
  /// or null when last week had no volume to compare with.
  double? get volumeChange {
    final before = lastWeekSoFar.volumeKg;
    if (before <= 0) return null;
    return (thisWeek.volumeKg - before) / before;
  }
}

/// Working sets: completed and not warm-ups.
int _workingSets(WorkoutDetail d) => d.exercises.fold(
  0,
  (n, e) =>
      n +
      e.sets.where((s) => s.isCompleted && s.setType.countsTowardStats).length,
);

/// Best Epley e1RM across [workouts] (weight × reps exercises, working
/// sets, 1–12 reps). Shared with the share card.
({String exercise, double e1rmKg})? bestLift(Iterable<WorkoutDetail> workouts) {
  ({String exercise, double e1rmKg})? top;
  for (final d in workouts) {
    for (final e in d.exercises) {
      if (e.exercise.trackingType != TrackingType.weightReps) continue;
      for (final s in e.sets) {
        if (!s.isCompleted || !s.setType.countsTowardStats) continue;
        if (s.weightKg == null || s.reps == null) continue;
        final est = estimateOneRepMax(s.weightKg!, s.reps!);
        if (est != null && (top == null || est > top.e1rmKg)) {
          top = (exercise: e.name, e1rmKg: est);
        }
      }
    }
  }
  return top;
}

WeekTotals _totals(Iterable<WorkoutDetail> workouts) {
  var minutes = 0, sets = 0, count = 0;
  var volume = 0.0;
  for (final d in workouts) {
    count++;
    minutes += (d.workout.durationSeconds ?? 0) ~/ 60;
    sets += _workingSets(d);
    volume += d.volumeKg;
  }
  return WeekTotals(
    workouts: count,
    minutes: minutes,
    sets: sets,
    volumeKg: volume,
  );
}

/// Builds the summary from completed workouts since last Monday
/// (anything older is ignored).
WeekSummary computeWeekSummary({
  required List<WorkoutDetail> workouts,
  required DateTime now,
}) {
  final monday = startOfWeek(now);
  final lastMonday = startOfWeek(monday.subtract(const Duration(days: 1)));
  final sameTimeLastWeek = now.subtract(const Duration(days: 7));

  final sorted = [...workouts]
    ..sort((a, b) => b.workout.startedAt.compareTo(a.workout.startedAt));
  final thisWeek = sorted
      .where((d) => !d.workout.startedAt.isBefore(monday))
      .toList();
  final lastWeek = sorted
      .where(
        (d) =>
            !d.workout.startedAt.isBefore(lastMonday) &&
            d.workout.startedAt.isBefore(monday),
      )
      .toList();

  final minutes = List.filled(7, 0);
  final ids = List.generate(7, (_) => <int>[]);
  final muscles = List.generate(7, (_) => <MuscleGroup, int>{});
  for (final d in thisWeek) {
    final i = d.workout.startedAt.weekday - 1;
    minutes[i] += (d.workout.durationSeconds ?? 0) ~/ 60;
    ids[i].add(d.workout.id);
    for (final e in d.exercises) {
      final n = e.sets
          .where((s) => s.isCompleted && s.setType.countsTowardStats)
          .length;
      if (n == 0) continue;
      final m = e.exercise.primaryMuscle;
      muscles[i][m] = (muscles[i][m] ?? 0) + n;
    }
  }

  return WeekSummary(
    weekStart: monday,
    now: now,
    thisWeek: _totals(thisWeek),
    lastWeekSoFar: _totals(
      lastWeek.where((d) => !d.workout.startedAt.isAfter(sameTimeLastWeek)),
    ),
    lastWeekTotal: lastWeek.length,
    days: [
      for (var i = 0; i < 7; i++)
        DayActivity(
          minutes: minutes[i],
          workoutIds: ids[i],
          muscleSets: muscles[i],
        ),
    ],
    topLift: bestLift(thisWeek),
  );
}

enum WeekPaceState { newWeek, onTrack, behind, goalHit }

/// Where the week stands against the workout goal.
class WeekPace {
  const WeekPace({
    required this.state,
    required this.toGo,
    required this.daysLeft,
    this.behindBy = 0,
  });

  final WeekPaceState state;

  /// Workouts still needed to reach the goal.
  final int toGo;

  /// Days left including today (Thursday → 4).
  final int daysLeft;
  final int behindBy;
}

/// Expected workouts by the end of today = goal × days so far ÷ 7, rounded
/// down; fewer than that is behind.
WeekPace weekPace({
  required int workouts,
  required int goal,
  required DateTime now,
}) {
  final daysLeft = 8 - now.weekday;
  final toGo = (goal - workouts).clamp(0, goal);
  if (goal > 0 && workouts >= goal) {
    return WeekPace(state: WeekPaceState.goalHit, toGo: 0, daysLeft: daysLeft);
  }
  final expected = goal * now.weekday ~/ 7;
  if (workouts == 0 && expected == 0) {
    return WeekPace(
      state: WeekPaceState.newWeek,
      toGo: toGo,
      daysLeft: daysLeft,
    );
  }
  if (workouts < expected) {
    return WeekPace(
      state: WeekPaceState.behind,
      toGo: toGo,
      daysLeft: daysLeft,
      behindBy: expected - workouts,
    );
  }
  return WeekPace(state: WeekPaceState.onTrack, toGo: toGo, daysLeft: daysLeft);
}

/// Consecutive weeks (ending now) in which at least [goal] workouts were
/// completed. Last week and earlier count back until a miss; this week is
/// added once its goal is reached, so an unfinished week never breaks it.
int weekStreak({
  required List<DateTime> workoutStarts,
  required int goal,
  required DateTime now,
}) {
  if (goal <= 0) return 0;
  final perWeek = <DateTime, int>{};
  for (final s in workoutStarts) {
    final w = startOfWeek(s);
    perWeek[w] = (perWeek[w] ?? 0) + 1;
  }
  final thisWeek = startOfWeek(now);
  var streak = (perWeek[thisWeek] ?? 0) >= goal ? 1 : 0;
  var week = thisWeek;
  while (true) {
    // Step back via a midweek day so daylight-saving shifts can't skip a week.
    week = startOfWeek(week.subtract(const Duration(days: 3)));
    if ((perWeek[week] ?? 0) < goal) break;
    streak++;
  }
  return streak;
}
