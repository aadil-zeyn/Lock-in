import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/exercise_photos.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../../statistics/presentation/progress_screen.dart';
import '../data/exercise_providers.dart';
import '../data/exercise_repository.dart';

class ExerciseDetailsScreen extends ConsumerWidget {
  const ExerciseDetailsScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseProvider(exerciseId));
    final exercise = exerciseAsync.value;

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: exerciseAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(
                icon: Icons.help_outline_rounded,
                title: 'Exercise not found',
                message: 'It may have been removed.',
              ),
      );
    }

    final usage = ref.watch(exerciseUsageProvider(exerciseId)).value ?? 0;
    final unit =
        ref.watch(userProfileProvider).value?.weightUnit ?? WeightUnit.kg;
    final secondary = exercise.secondaryMuscleList;
    final color = exercise.primaryMuscle.color;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (exercise.isCustom && !exercise.isArchived)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.editExercise(exercise.id)),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) => value == 'archive'
                ? _archive(context, ref, exercise)
                : _restore(context, ref, exercise),
            itemBuilder: (context) => [
              if (exercise.isArchived)
                const PopupMenuItem(
                  value: 'restore',
                  child: Text('Restore to library'),
                )
              else
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
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
          Text(exercise.name, style: text.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Pill(
                label: exercise.primaryMuscle.region.label,
                color: color,
                icon: Icons.bolt_rounded,
              ),
              if (exercise.isCustom)
                const _Pill(
                  label: 'Custom',
                  color: AppColors.accent,
                  icon: Icons.person_rounded,
                ),
              if (exercise.isArchived)
                const _Pill(
                  label: 'Archived',
                  color: AppColors.textSecondary,
                  icon: Icons.inventory_2_outlined,
                ),
            ],
          ),
          if (exercise.isArchived) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: AppColors.surfaceHigh,
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Hidden from the library. Your past workouts still '
                      'include it.',
                      style: text.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _restore(context, ref, exercise),
                    child: const Text('Restore'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (exercisePhotoFrames(exercise.name, isCustom: exercise.isCustom)
              case final photo?) ...[
            ExercisePhoto(
              start: photo.start,
              end: photo.end,
              label: exercise.name,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Muscle diagram with a text legend (diagram alone is colour-only).
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppGradients.tint(color),
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                MuscleMap(
                  primary: exercise.primaryMuscle,
                  secondary: secondary,
                  height: 200,
                ),
                const SizedBox(height: AppSpacing.lg),
                _LegendRow(
                  swatch: color,
                  label: 'Primary',
                  value: exercise.primaryMuscle.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                _LegendRow(
                  swatch: color.withValues(alpha: 0.45),
                  label: 'Secondary',
                  value: secondary.isEmpty
                      ? 'None'
                      : secondary.map((m) => m.label).join(', '),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: exercise.equipment.icon,
                    color: AppColors.volume,
                    label: 'Equipment',
                    value: exercise.equipment.label,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _InfoTile(
                    icon: exercise.trackingType.icon,
                    color: AppColors.time,
                    label: 'Tracking',
                    value: exercise.trackingType.label,
                  ),
                ),
              ],
            ),
          ),
          if (exercise.description != null) ...[
            const SectionHeader('How to'),
            AppCard(child: Text(exercise.description!, style: text.bodyLarge)),
          ],
          const SectionHeader('Performance'),
          if (usage == 0)
            const EmptyState(
              compact: true,
              icon: Icons.show_chart_rounded,
              title: 'No history yet',
              message:
                  'Log it in a workout to see your best sets and progress '
                  'chart here.',
            )
          else ...[
            ExerciseProgressCard(
              exercise: exercise,
              unit: unit,
              linkToDetails: false,
            ),
            const SizedBox(height: AppSpacing.md),
            StatCard(
              label: 'Workouts',
              value: '$usage',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.workouts,
              caption: 'Sessions with this exercise',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${exercise.name}?'),
        content: const Text(
          'It disappears from the library and the exercise picker. Workouts '
          'you\'ve already logged keep it, and you can restore it any time '
          'from Archived exercises.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Read the repository now: Undo runs after this screen has closed.
    final repo = ref.read(exerciseRepositoryProvider);
    await repo.archive(exercise.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${exercise.name} archived'),
          // Actions make snackbars stick by default; let it time out.
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.restore(exercise.id),
          ),
        ),
      );
    context.pop();
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(exerciseRepositoryProvider).restore(exercise.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${exercise.name} is back in the library')),
        );
    } on DuplicateExerciseNameException {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Another exercise is already called '
              '"${exercise.name}". Rename that one first.',
            ),
          ),
        );
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.swatch,
    required this.label,
    required this.value,
  });

  final Color swatch;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: swatch,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Text(value, style: text.titleSmall)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(value, style: text.titleMedium),
        ],
      ),
    );
  }
}
