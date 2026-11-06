import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
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
        const SizedBox(height: AppSpacing.md),
        _StartWorkoutCard(active: active),
        const SectionHeader('This week'),
        WeeklyActivityCard(workouts: week, now: now),
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
        const SectionHeader('Body weight'),
        if (weights.isEmpty)
          EmptyState(
            compact: true,
            icon: Icons.monitor_weight_outlined,
            title: 'Track your weight',
            message: 'Log it now and then to see the trend.',
            actionLabel: 'Add entry',
            onAction: () => showComingSoon(context, 'Body tracking'),
          )
        else
          _BodyWeightCard(entries: weights, unit: unit),
        const SectionHeader('Personal records'),
        const EmptyState(
          compact: true,
          icon: Icons.emoji_events_outlined,
          title: 'No records yet',
          message: 'Beat a previous best and it lands here.',
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : null;
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.surfaceHigh,
      child: initial == null
          ? const Icon(Icons.person_rounded, color: AppColors.textSecondary)
          : Text(initial,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    );
  }
}

class _StartWorkoutCard extends StatelessWidget {
  const _StartWorkoutCard({required this.active});
  final Workout? active;

  @override
  Widget build(BuildContext context) {
    final resuming = active != null;
    return AppCard(
      color: AppColors.accent,
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: () => showComingSoon(
          context, resuming ? 'Resuming workouts' : 'The workout engine'),
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
                    fontWeight: FontWeight.w500,
                    color: AppColors.onAccent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.onAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              resuming ? Icons.play_arrow_rounded : Icons.add_rounded,
              color: AppColors.accent,
              size: 30,
            ),
          ),
        ],
      ),
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
      onTap: () => showComingSoon(context, 'Workout details'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workout.name, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatShortDate(workout.startedAt)} · ${formatDuration(duration)}',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _BodyWeightCard extends StatelessWidget {
  const _BodyWeightCard({required this.entries, required this.unit});
  final List<BodyMeasurement> entries;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final latest = kgToDisplay(entries.first.measuredValue, unit);
    String? caption;
    if (entries.length > 1) {
      final diff = latest - kgToDisplay(entries[1].measuredValue, unit);
      final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '±');
      caption =
          '$sign${formatNumber(diff.abs())} ${unitLabel(unit)} since last entry';
    }
    return StatCard(
      label: 'Latest · ${formatShortDate(entries.first.recordedAt)}',
      value: formatNumber(latest),
      unit: unitLabel(unit),
      caption: caption,
      icon: Icons.monitor_weight_outlined,
    );
  }
}
