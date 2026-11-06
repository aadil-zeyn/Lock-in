import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/presentation/set_row.dart';
import '../data/day_card.dart';
import '../data/share_stats.dart';

/// Story cards are laid out at 360 × 640 logical px (9:16) and captured at
/// 3× → 1080 × 1920, Instagram's story size. Fixed text scaling keeps the
/// layout identical on every phone.
const storySize = Size(360, 640);

String _thousands(num n) => n.round().toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

String _volume(double kg, WeightUnit unit) {
  final v = kgToDisplay(kg, unit);
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
  return _thousands(v);
}

class _StoryFrame extends StatelessWidget {
  const _StoryFrame({required this.child, required this.glow});
  final Widget child;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: storySize,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Colors.black),
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -100,
                child: _Glow(color: glow, size: 360),
              ),
              Positioned(
                bottom: -140,
                left: -120,
                child: _Glow(color: AppColors.time, size: 340),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.right});
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ActivityRings(
          size: 26,
          strokeWidth: 4,
          gap: 2,
          rings: [
            RingData(progress: 0.8, color: AppColors.workouts),
            RingData(progress: 0.6, color: AppColors.time),
            RingData(progress: 0.45, color: AppColors.sets),
          ],
        ),
        const SizedBox(width: 8),
        const Text(
          'LOCK-IN',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            right,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.color,
    this.unit,
  });
  final String label;
  final String value;
  final String? unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Train consistently. Track intelligently. Lock in.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
    );
  }
}

/// "This week": rings, trained days, key numbers, best lift.
class WeekStoryCard extends StatelessWidget {
  const WeekStoryCard({
    super.key,
    required this.data,
    required this.unit,
    required this.workoutGoal,
    required this.minutesGoal,
    required this.setsGoal,
  });

  final WeekShare data;
  final WeightUnit unit;
  final int workoutGoal;
  final int minutesGoal;
  final int setsGoal;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final d = data;
    final u = unitLabel(unit);
    final change = d.weightChangeKg;
    return _StoryFrame(
      glow: AppColors.workouts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(
            right: 'WEEK OF ${formatShortDate(d.weekStart).toUpperCase()}',
          ),
          const SizedBox(height: 18),
          Center(
            child: ActivityRings(
              size: 180,
              strokeWidth: 16,
              gap: 5,
              rings: [
                RingData(
                  progress: workoutGoal == 0 ? 0 : d.workouts / workoutGoal,
                  color: AppColors.workouts,
                ),
                RingData(
                  progress: minutesGoal == 0 ? 0 : d.minutes / minutesGoal,
                  color: AppColors.time,
                ),
                RingData(
                  progress: setsGoal == 0 ? 0 : d.sets / setsGoal,
                  color: AppColors.sets,
                ),
              ],
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${d.workouts}',
                    style: const TextStyle(
                      fontSize: 40,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    d.workouts == 1 ? 'workout' : 'workouts',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d.trainedDays[i]
                            ? AppColors.workouts
                            : AppColors.surfaceHigh,
                      ),
                      child: d.trainedDays[i]
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.onAccent,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _days[i],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Active time',
                  value: formatDuration(Duration(minutes: d.minutes)),
                  color: AppColors.time,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  label: 'Working sets',
                  value: '${d.sets}',
                  color: AppColors.sets,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Volume',
                  value: _volume(d.volumeKg, unit),
                  unit: u,
                  color: AppColors.volume,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: d.avgKcal != null
                    ? _Tile(
                        label: 'Avg calories',
                        value: _thousands(d.avgKcal!),
                        unit: 'kcal',
                        color: AppColors.food,
                      )
                    : _Tile(
                        label: 'Weight 30d',
                        value: change == null
                            ? '—'
                            : '${change > 0
                                      ? '+'
                                      : change < 0
                                      ? '−'
                                      : '±'}'
                                  '${formatNumber(double.parse(kgToDisplay(change.abs(), unit).toStringAsFixed(1)))}',
                        unit: change == null ? null : u,
                        color: AppColors.body,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (d.topLift != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: AppGradients.energy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.onAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOP LIFT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.onAccent,
                          ),
                        ),
                        Text(
                          d.topLift!.exercise,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${formatNumber(double.parse(kgToDisplay(d.topLift!.e1rmKg, unit).toStringAsFixed(1)))} $u',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onAccent,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          const _Footer(),
        ],
      ),
    );
  }
}

/// "Last workout": name, date, time / sets / volume, exercises with sets.
class WorkoutStoryCard extends StatelessWidget {
  const WorkoutStoryCard({super.key, required this.detail, required this.unit});
  final WorkoutDetail detail;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final w = detail.workout;
    final mins = (w.durationSeconds ?? 0) ~/ 60;
    final shown = detail.exercises.take(6).toList();
    final more = detail.exercises.length - shown.length;

    return _StoryFrame(
      glow: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(right: formatLongDate(w.startedAt).toUpperCase()),
          const SizedBox(height: 28),
          const Text(
            'WORKOUT COMPLETE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            w.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'Time',
                  value: mins == 0
                      ? '—'
                      : formatDuration(Duration(minutes: mins)),
                  color: AppColors.time,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Tile(
                  label: 'Sets',
                  value: '${detail.completedSets}',
                  color: AppColors.sets,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Tile(
                  label: 'Volume',
                  value: _volume(detail.volumeKg, unit),
                  color: AppColors.volume,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final e in shown)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  IconBadge(
                    text: e.exercise.primaryMuscle.initials,
                    color: e.exercise.primaryMuscle.color,
                    size: 30,
                    circle: false,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          e.sets
                              .where((s) => s.isCompleted)
                              .map(
                                (s) => describePrevious(
                                  (
                                    weightKg: s.weightKg,
                                    reps: s.reps,
                                    seconds: s.durationSeconds,
                                    band: s.bandLevel,
                                  ),
                                  e.exercise.trackingType,
                                  unit,
                                ),
                              )
                              .join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (more > 0)
            Text(
              '+ $more more',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          const Spacer(),
          const _Footer(),
        ],
      ),
    );
  }
}

/// "Day 311/365": today's ticks (steps, workout, protein, calories), the
/// year so far, and the steps streak. With [photo] (e.g. a pump pic) the
/// photo fills the card and the stats sit on a dark fade at the bottom.
class DayStoryCard extends StatelessWidget {
  const DayStoryCard({super.key, required this.data, this.photo});
  final DayCardData data;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final year = d.day / d.yearDays;
    final steps = d.steps;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Brand(right: formatLongDate(d.date).toUpperCase()),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'DAY ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
              Text(
                '${d.day}',
                style: const TextStyle(
                  fontSize: 84,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  ' / ${d.yearDays}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: year,
            minHeight: 6,
            color: AppColors.accent,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(year * 100).round()}% of ${d.date.year} · '
          '${d.yearDays - d.day} days left',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        _Tick(
          done: d.stepsOk,
          label: 'Steps',
          value: steps == null
              ? 'connect Health Connect'
              : '${_thousands(steps)} / ${_thousands(d.stepsGoal)}',
          color: AppColors.steps,
        ),
        _Tick(
          done: d.workoutOk,
          label: 'Workout',
          value: d.workoutName ?? 'rest day',
          color: AppColors.workouts,
        ),
        _Tick(
          done: d.proteinOk,
          label: 'Protein',
          value: '${d.proteinG} / ${d.proteinGoal} g',
          color: AppColors.protein,
        ),
        _Tick(
          done: d.kcalOk,
          label: 'Calories',
          value: '${_thousands(d.kcal)} / ${_thousands(d.kcalGoal)} kcal',
          color: AppColors.food,
        ),
        if (d.streak >= 2) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.accent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${d.streak}-day ${_thousands(d.stepsGoal)}-step streak',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const _Footer(),
      ],
    );

    if (photo == null) {
      return _StoryFrame(glow: AppColors.accent, child: content);
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: storySize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true),
            // Fade to black behind the text so it stays readable on any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.18, 0.42, 0.62, 1],
                  colors: [
                    Color(0x99000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xD9000000),
                    Color(0xF7000000),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({
    required this.done,
    required this.label,
    required this.value,
    required this.color,
  });
  final bool done;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : Colors.transparent,
              border: done
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: AppColors.onAccent,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
