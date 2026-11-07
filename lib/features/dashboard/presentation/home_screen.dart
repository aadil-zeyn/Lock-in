import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../body/presentation/log_weight_sheet.dart';
import '../../health/data/health_providers.dart';
import '../data/dashboard_providers.dart';
import '../data/week_summary.dart';
import 'today_card.dart';
import 'weekly_activity_card.dart';
import 'weekly_goals_sheet.dart';

/// "2–8 Nov", or "30 Nov – 6 Dec" across a month boundary.
String weekRangeLabel(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  if (monday.month == sunday.month) {
    return '${monday.day}–${formatShortDate(sunday)}';
  }
  return '${formatShortDate(monday)} – ${formatShortDate(sunday)}';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final profile = ref.watch(userProfileProvider).value;
    final summary =
        ref.watch(weekSummaryProvider).value ?? WeekSummary.empty(now);
    final streak = ref.watch(weekStreakProvider).value ?? 0;
    final latest = ref.watch(latestWorkoutProvider).value;
    final weights = ref.watch(recentBodyWeightsProvider).value ?? const [];
    // Pull new weigh-ins from Health Connect once per launch (no-op if off).
    ref.watch(healthAutoSyncProvider);

    final name = profile?.name;
    final unit = profile?.weightUnit ?? WeightUnit.kg;

    return TabPage(
      subtitle: formatLongDate(now),
      title: name == null || name.isEmpty ? 'Hey there' : 'Hey $name',
      trailing: _Avatar(name: name),
      children: [
        const SizedBox(height: AppSpacing.lg),
        if (profile != null && profile.heightCm == null) ...[
          AppCard(
            color: AppColors.surfaceHigh,
            onTap: () => context.push(Routes.editProfile),
            child: const Row(
              children: [
                IconBadge(icon: Icons.badge_rounded, color: AppColors.accent),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Finish your profile — height, age and goal give you '
                    'calorie and protein targets made for you.',
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const TodayCard(),
        const SizedBox(height: AppSpacing.md),
        const QuickActions(),
        SectionHeader(
          'This week',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekRangeLabel(summary.weekStart),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: 'Share your week',
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                onPressed: () => context.push(Routes.shareProgress),
              ),
            ],
          ),
        ),
        WeeklyActivityCard(
          summary: summary,
          unit: unit,
          streak: streak,
          workoutGoal: profile?.weeklyWorkoutGoal ?? 3,
          minutesGoal: profile?.weeklyMinutesGoal ?? 180,
          setsGoal: profile?.weeklySetsGoal ?? 45,
          onEditGoals: () => showWeeklyGoalsSheet(context),
          onOpenWorkout: (id) => context.push(Routes.workoutSummary(id)),
        ),
        const SizedBox(height: AppSpacing.md),
        _BodyWeightRow(entries: weights, unit: unit),
        const SectionHeader('Last workout'),
        if (latest == null)
          const EmptyState(
            compact: true,
            icon: Icons.history_rounded,
            title: 'No workouts yet',
            message: 'Your most recent session will show up here.',
          )
        else
          _LatestWorkoutCard(workout: latest),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.isNotEmpty)
        ? name![0].toUpperCase()
        : null;
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.energy,
      ),
      alignment: Alignment.center,
      child: initial == null
          ? const Icon(Icons.person_rounded, color: AppColors.onAccent)
          : Text(
              initial,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.onAccent,
              ),
            ),
    );
  }
}

/// Slim full-width body-weight row; tap to log.
class _BodyWeightRow extends StatelessWidget {
  const _BodyWeightRow({required this.entries, required this.unit});
  final List<BodyMeasurement> entries;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String? value;
    var caption = 'Tap to log your weight';
    if (entries.isNotEmpty) {
      final latest = kgToDisplay(entries.first.measuredValue, unit);
      value = formatNumber(latest);
      caption = formatShortDate(entries.first.recordedAt);
      if (entries.length > 1) {
        final diff = latest - kgToDisplay(entries[1].measuredValue, unit);
        final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '±');
        caption =
            '$sign${formatNumber(diff.abs())} ${unitLabel(unit)} · $caption';
      }
    }
    return AppCard(
      onTap: () => showLogWeightSheet(context),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.monitor_weight_rounded,
            color: AppColors.body,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body weight',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value ?? '—',
                        style: AppText.metricM.copyWith(fontSize: 18),
                      ),
                      TextSpan(
                        text: ' ${unitLabel(unit)}',
                        style: AppText.unit,
                      ),
                      TextSpan(
                        text: '  $caption',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.add_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// The most recent completed workout; tap for its summary.
class _LatestWorkoutCard extends StatelessWidget {
  const _LatestWorkoutCard({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final duration = Duration(seconds: workout.durationSeconds ?? 0);
    return AppCard(
      onTap: () => context.push(Routes.workoutSummary(workout.id)),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.fitness_center_rounded,
            color: AppColors.workouts,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.name, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatShortDate(workout.startedAt)} · ${formatDuration(duration)}',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
