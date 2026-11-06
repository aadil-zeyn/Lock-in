import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/workout_repository.dart';
import 'set_row.dart';

/// Shown right after finishing, and reusable for any completed workout.
class WorkoutSummaryScreen extends ConsumerWidget {
  const WorkoutSummaryScreen({super.key, required this.workoutId});
  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId)).value;
    final unit =
        ref.watch(userProfileProvider).value?.weightUnit ?? WeightUnit.kg;
    final text = Theme.of(context).textTheme;

    if (detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final w = detail.workout;
    final duration = Duration(seconds: w.durationSeconds ?? 0);
    final volume = kgToDisplay(detail.volumeKg, unit);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (_) => _delete(context, ref, w.name),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete workout',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: ActivityRings(
              size: 150,
              strokeWidth: 15,
              semanticsLabel: 'Workout complete',
              rings: const [
                RingData(progress: 1, color: AppColors.workouts),
                RingData(progress: 1, color: AppColors.time),
                RingData(progress: 1, color: AppColors.sets),
              ],
              center: const Icon(
                Icons.check_rounded,
                size: 40,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Workout complete',
            textAlign: TextAlign.center,
            style: text.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${w.name} · ${formatShortDate(w.startedAt)}',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Time',
                    value: formatDuration(duration),
                    icon: Icons.timer_rounded,
                    color: AppColors.time,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatCard(
                    label: 'Sets',
                    value: '${detail.completedSets}',
                    icon: Icons.layers_rounded,
                    color: AppColors.sets,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          StatCard(
            label: 'Volume',
            value: formatNumber(volume.roundToDouble()),
            unit: unitLabel(unit),
            icon: Icons.bar_chart_rounded,
            color: AppColors.volume,
            caption: 'Weight × reps of ticked working sets',
          ),
          const SectionHeader('Exercises'),
          for (final e in detail.exercises) ...[
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    text: e.exercise.primaryMuscle.initials,
                    color: e.exercise.primaryMuscle.color,
                    size: 36,
                    circle: false,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          e.sets
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
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Done',
            icon: Icons.check_rounded,
            onPressed: () => _close(context),
          ),
        ],
      ),
    );
  }

  /// Back to wherever the summary was opened from (History, Home), or Home.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
          'This workout and all its sets are removed from history, charts '
          'and records. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    _close(context);
    await ref.read(workoutRepositoryProvider).deleteCompleted(workoutId);
  }
}
