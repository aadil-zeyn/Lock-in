import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../body/presentation/log_weight_sheet.dart';
import '../../food/data/food_repository.dart';
import '../../food/presentation/food_picker_sheet.dart';
import '../../health/data/health_providers.dart';
import '../../workout/presentation/workout_actions.dart';
import '../data/dashboard_providers.dart';

/// Fallback daily step target (the profile's goal is used when set).
const dailyStepsGoal = 8000;

String _thousands(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// Home hero: today's steps, calories and protein, plus workout status.
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final profile = ref.watch(userProfileProvider).value;
    final health = ref.watch(healthStatusProvider).value;
    final week7 = ref.watch(weekStepsProvider).value;
    final steps = week7?.last;
    // Just after midnight today is 0 — show yesterday's total alongside.
    final yesterday = week7 != null && week7.length > 1
        ? week7[week7.length - 2]
        : null;
    final food = totalsFor(
      ref.watch(dayFoodProvider(dayStart(now))).value ?? const [],
    );
    final active = ref.watch(activeWorkoutProvider).value;
    final week = ref.watch(thisWeekWorkoutsProvider).value ?? const [];
    final today = week
        .where((w) => dayStart(w.startedAt) == dayStart(now))
        .toList();
    final kcalGoal = profile?.dailyKcalGoal ?? 2200;
    final proteinGoal = profile?.dailyProteinGoal ?? 140;
    final weekGoal = profile?.weeklyWorkoutGoal ?? 3;
    final stepsConnected = health?.connected ?? false;

    final (statusIcon, statusColor, statusText) = active != null
        ? (
            Icons.play_circle_fill_rounded,
            AppColors.accent,
            'Workout in progress · ${active.name}',
          )
        : today.isNotEmpty
        ? (
            Icons.check_circle_rounded,
            AppColors.sets,
            'Trained today · ${today.first.name}',
          )
        : (
            Icons.bedtime_rounded,
            AppColors.textSecondary,
            'Rest day so far · ${week.length} of $weekGoal this week',
          );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('TODAY', style: AppText.overline),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TodayMetric(
                value: stepsConnected && steps != null
                    ? _thousands(steps)
                    : '—',
                label: !stepsConnected
                    ? 'steps · connect'
                    : (steps ?? 0) == 0 && (yesterday ?? 0) > 0
                    ? 'yesterday ${_thousands(yesterday!)}'
                    : 'steps',
                progress: steps == null
                    ? 0
                    : steps / (profile?.dailyStepsGoal ?? dailyStepsGoal),
                color: AppColors.steps,
                // Step history lives on the Progress tab.
                onTap: () => stepsConnected
                    ? context.go(Routes.progress)
                    : context.push(Routes.healthConnect),
              ),
              _TodayMetric(
                value: _thousands(food.kcal),
                label: 'of ${_thousands(kcalGoal)} kcal',
                progress: kcalGoal == 0 ? 0 : food.kcal / kcalGoal,
                color: AppColors.food,
                onTap: () => context.go(Routes.food),
              ),
              _TodayMetric(
                value: '${food.proteinG.round()} g',
                label: 'of $proteinGoal g protein',
                progress: proteinGoal == 0 ? 0 : food.proteinG / proteinGoal,
                color: AppColors.protein,
                onTap: () => context.go(Routes.food),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => active != null
                ? context.push(Routes.activeWorkout)
                : context.go(Routes.workout),
            child: Row(
              children: [
                Icon(statusIcon, size: 20, color: statusColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({
    required this.value,
    required this.label,
    required this.progress,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final double progress;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppText.metricM),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Start/resume workout, log food, log weight — one tap each.
class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).value != null;
    return Row(
      children: [
        _Action(
          icon: active ? Icons.play_arrow_rounded : Icons.add_rounded,
          label: active ? 'Resume' : 'Workout',
          color: AppColors.accent,
          onTap: () => startOrResumeWorkout(context, ref),
        ),
        const SizedBox(width: AppSpacing.md),
        _Action(
          icon: Icons.restaurant_rounded,
          label: 'Food',
          color: AppColors.food,
          onTap: () => showFoodPicker(context, day: dayStart(DateTime.now())),
        ),
        const SizedBox(width: AppSpacing.md),
        _Action(
          icon: Icons.monitor_weight_rounded,
          label: 'Weight',
          color: AppColors.body,
          onTap: () => showLogWeightSheet(context),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            IconBadge(icon: icon, color: color, size: 44),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
