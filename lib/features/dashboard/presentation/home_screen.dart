import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../workout/presentation/workout_actions.dart';
import '../data/dashboard_providers.dart';
import 'weekly_activity_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final profile = ref.watch(userProfileProvider).value;
    final active = ref.watch(activeWorkoutProvider).value;
    final week = ref.watch(thisWeekWorkoutsProvider).value ?? const [];
    final sets = ref.watch(thisWeekSetsProvider).value ?? 0;
    final latest = ref.watch(latestWorkoutProvider).value;
    final weights = ref.watch(recentBodyWeightsProvider).value ?? const [];

    final name = profile?.name;
    final unit = profile?.weightUnit ?? WeightUnit.kg;

    return TabPage(
      subtitle: formatLongDate(now),
      title: name == null || name.isEmpty
          ? greetingFor(now)
          : '${greetingFor(now)}, $name',
      trailing: _Avatar(name: name),
      children: [
        const SizedBox(height: AppSpacing.lg),
        WeeklyActivityCard(
          workouts: week,
          sets: sets,
          now: now,
          workoutGoal: profile?.weeklyWorkoutGoal ?? 3,
          minutesGoal: profile?.weeklyMinutesGoal ?? 180,
          setsGoal: profile?.weeklySetsGoal ?? 45,
        ),
        const SizedBox(height: AppSpacing.md),
        _StartWorkoutCard(active: active),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BodyWeightTile(entries: weights, unit: unit),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: StatCard(
                  label: 'Records',
                  value: '0',
                  unit: 'PRs',
                  caption: 'Beat a best to earn one',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.records,
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

class _StartWorkoutCard extends ConsumerWidget {
  const _StartWorkoutCard({required this.active});
  final Workout? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resuming = active != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.energy,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => startOrResumeWorkout(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resuming ? 'Resume workout' : 'Start workout',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppColors.onAccent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        resuming
                            ? active!.name
                            : 'Empty session or one of your routines',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onAccent.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.onAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    resuming ? Icons.play_arrow_rounded : Icons.add_rounded,
                    color: AppColors.accent,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
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
        onTap: () => showComingSoon(context, 'Body tracking'),
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
    );
  }
}

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
