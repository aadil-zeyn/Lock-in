import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: 'Progress',
      children: [
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: StatCard(label: 'Workouts', value: '0')),
            SizedBox(width: AppSpacing.md),
            Expanded(child: StatCard(label: 'Volume', value: '0', unit: 'kg')),
          ],
        ),
        SectionHeader('Strength'),
        EmptyState(
          compact: true,
          icon: Icons.show_chart_rounded,
          title: 'Charts need data',
          message: 'Log a couple of workouts to see your lifts trend upward.',
        ),
      ],
    );
  }
}
