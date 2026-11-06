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
import 'today_card.dart';
import 'weekly_activity_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final profile = ref.watch(userProfileProvider).value;
    final week = ref.watch(thisWeekWorkoutsProvider).value ?? const [];
    final sets = ref.watch(thisWeekSetsProvider).value ?? 0;
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
        const TodayCard(),
        const SizedBox(height: AppSpacing.md),
        const QuickActions(),
        const SectionHeader('This week'),
        WeeklyActivityCard(
          workouts: week,
          sets: sets,
          now: now,
          workoutGoal: profile?.weeklyWorkoutGoal ?? 3,
          minutesGoal: profile?.weeklyMinutesGoal ?? 180,
          setsGoal: profile?.weeklySetsGoal ?? 45,
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BodyWeightTile(entries: weights, unit: unit),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  label: 'Share',
                  value: 'Story',
                  caption: 'Your week as an Instagram card',
                  icon: Icons.ios_share_rounded,
                  color: AppColors.streak,
                  onTap: () => context.push(Routes.shareProgress),
                ),
              ),
            ],
          ),
        ),
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

class _BodyWeightTile extends StatelessWidget {
  const _BodyWeightTile({required this.entries, required this.unit});
  final List<BodyMeasurement> entries;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return StatCard(
        label: 'Body weight',
        value: '—',
        unit: unitLabel(unit),
        caption: 'Tap to log your weight',
        icon: Icons.monitor_weight_rounded,
        color: AppColors.body,
        onTap: () => showLogWeightSheet(context),
      );
    }
    final latest = kgToDisplay(entries.first.measuredValue, unit);
    var caption = formatShortDate(entries.first.recordedAt);
    if (entries.length > 1) {
      final diff = latest - kgToDisplay(entries[1].measuredValue, unit);
      final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '±');
      caption =
          '$sign${formatNumber(diff.abs())} ${unitLabel(unit)} · $caption';
    }
    return StatCard(
      label: 'Body weight',
      value: formatNumber(latest),
      unit: unitLabel(unit),
      caption: caption,
      icon: Icons.monitor_weight_rounded,
      color: AppColors.body,
      onTap: () => showLogWeightSheet(context),
    );
  }
}

/// Today's steps from Health Connect, or a prompt to connect it.
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
