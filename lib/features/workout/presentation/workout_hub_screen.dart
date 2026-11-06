import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/data/history_providers.dart';
import '../../history/presentation/history_screen.dart';
import 'workout_actions.dart';

/// Workout tab: start a session, manage routines, browse the library.
class WorkoutHubScreen extends ConsumerWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider).value ?? const [];
    return TabPage(
      title: 'Workout',
      children: [
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Start empty workout',
          icon: Icons.add_rounded,
          onPressed: () => startOrResumeWorkout(context, ref),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _HubTile(
                icon: Icons.menu_book_rounded,
                color: AppColors.volume,
                title: 'Exercises',
                subtitle: 'Library & custom',
                onTap: () => context.push(Routes.exercises),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _HubTile(
                icon: Icons.add_circle_outline_rounded,
                color: AppColors.sets,
                title: 'New exercise',
                subtitle: 'Create your own',
                onTap: () => context.push(Routes.newExercise),
              ),
            ),
          ],
        ),
        SectionHeader(
          'Recent workouts',
          actionLabel: history.isEmpty ? null : 'See all',
          onAction: () => context.push(Routes.history),
        ),
        if (history.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.history_rounded,
            title: 'No workouts yet',
            message: 'Finished sessions show up here, newest first.',
          )
        else
          for (final item in history.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: WorkoutHistoryTile(item: item),
            ),
        SectionHeader(
          'Routines',
          actionLabel: 'New',
          onAction: () => showComingSoon(context, 'Routines'),
        ),
        const EmptyState(
          compact: true,
          icon: Icons.view_list_rounded,
          title: 'No routines yet',
          message: 'Save a Push, Pull or Legs day and start it in one tap.',
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color, size: 44),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
