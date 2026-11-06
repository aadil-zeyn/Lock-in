import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Workout tab: start a session, manage routines, browse the library.
class WorkoutHubScreen extends StatelessWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Workout',
      children: [
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Start empty workout',
          icon: Icons.add_rounded,
          onPressed: () => showComingSoon(context, 'The workout engine'),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: 'Exercise library',
          icon: Icons.menu_book_rounded,
          onPressed: () => context.push(Routes.exercises),
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
