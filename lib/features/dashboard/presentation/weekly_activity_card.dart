import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/widgets.dart';

/// Workouts this week + a Mon–Sun dot strip.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({
    super.key,
    required this.workouts,
    required this.now,
  });

  final List<Workout> workouts;
  final DateTime now;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final trainedDays = workouts.map((w) => w.startedAt.weekday).toSet();
    final totalSeconds =
        workouts.fold<int>(0, (sum, w) => sum + (w.durationSeconds ?? 0));
    final today = now.weekday;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Metric(
                  label: 'WORKOUTS',
                  value: '${workouts.length}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'TIME',
                  value: formatDuration(Duration(seconds: totalSeconds)),
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.overline),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppText.metricL),
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
              color: trained ? AppColors.accent : AppColors.surfaceHigh,
              border: isToday && !trained
                  ? Border.all(color: AppColors.accent, width: 2)
                  : null,
            ),
            // A tick as well as colour, so state isn't colour-only.
            child: trained
                ? const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.onAccent)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            letter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isFuture ? AppColors.textTertiary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
