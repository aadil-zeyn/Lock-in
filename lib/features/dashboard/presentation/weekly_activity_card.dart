import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/widgets.dart';

/// Band-style weekly summary: three activity rings (workouts, minutes,
/// working sets) against the user's goals, plus a Mon–Sun strip.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({
    super.key,
    required this.workouts,
    required this.sets,
    required this.now,
    this.workoutGoal = 3,
    this.minutesGoal = 180,
    this.setsGoal = 45,
  });

  final List<Workout> workouts;
  final int sets;
  final DateTime now;
  final int workoutGoal;
  final int minutesGoal;
  final int setsGoal;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final trainedDays = workouts.map((w) => w.startedAt.weekday).toSet();
    final minutes =
        workouts.fold<int>(0, (sum, w) => sum + (w.durationSeconds ?? 0)) ~/ 60;
    final today = now.weekday;

    double ratio(int value, int goal) => goal <= 0 ? 0 : value / goal;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            children: [
              ActivityRings(
                size: 132,
                strokeWidth: 13,
                semanticsLabel:
                    '${workouts.length} of $workoutGoal workouts, $minutes of '
                    '$minutesGoal minutes, $sets of $setsGoal sets this week',
                rings: [
                  RingData(
                    progress: ratio(workouts.length, workoutGoal),
                    color: AppColors.workouts,
                  ),
                  RingData(
                    progress: ratio(minutes, minutesGoal),
                    color: AppColors.time,
                  ),
                  RingData(
                    progress: ratio(sets, setsGoal),
                    color: AppColors.sets,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RingLegend(
                      icon: Icons.local_fire_department_rounded,
                      color: AppColors.workouts,
                      value: '${workouts.length}',
                      goal: '/$workoutGoal',
                      label: 'Workouts',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RingLegend(
                      icon: Icons.timer_rounded,
                      color: AppColors.time,
                      value: '$minutes',
                      goal: '/$minutesGoal min',
                      label: 'Active time',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _RingLegend(
                      icon: Icons.layers_rounded,
                      color: AppColors.sets,
                      value: '$sets',
                      goal: '/$setsGoal',
                      label: 'Working sets',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                _DayDot(
                  letter: _dayLetters[day - 1],
                  trained: trainedDays.contains(day),
                  isToday: day == today,
                  isFuture: day > today,
                ),
            ],
          ),
          if (workouts.isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No sessions yet this week — ${formatShortDate(startOfWeek(now))} onwards.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RingLegend extends StatelessWidget {
  const _RingLegend({
    required this.icon,
    required this.color,
    required this.value,
    required this.goal,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String goal;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: AppText.metricM.copyWith(color: color),
                    ),
                    TextSpan(text: goal, style: AppText.unit),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.trained,
    required this.isToday,
    required this.isFuture,
  });

  final String letter;
  final bool trained;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: trained ? 'Trained' : 'Rest',
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: trained ? AppColors.workouts : AppColors.surfaceHigh,
              border: isToday && !trained
                  ? Border.all(color: AppColors.workouts, width: 2)
                  : null,
            ),
            // A tick as well as colour, so state isn't colour-only.
            child: trained
                ? const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.onAccent,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            letter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday
                  ? AppColors.textPrimary
                  : isFuture
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
