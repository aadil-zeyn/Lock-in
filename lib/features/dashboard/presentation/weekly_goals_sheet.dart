import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_providers.dart';

/// Bottom sheet to change the three weekly ring goals.
Future<void> showWeeklyGoalsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _WeeklyGoalsSheet(),
  );
}

class _WeeklyGoalsSheet extends ConsumerStatefulWidget {
  const _WeeklyGoalsSheet();

  @override
  ConsumerState<_WeeklyGoalsSheet> createState() => _WeeklyGoalsSheetState();
}

class _WeeklyGoalsSheetState extends ConsumerState<_WeeklyGoalsSheet> {
  late int _workouts;
  late int _minutes;
  late int _sets;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(userProfileProvider).value;
    _workouts = p?.weeklyWorkoutGoal ?? 3;
    _minutes = p?.weeklyMinutesGoal ?? 180;
    _sets = p?.weeklySetsGoal ?? 45;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await setWeeklyGoals(
      ref.read(databaseProvider),
      workouts: _workouts,
      minutes: _minutes,
      sets: _sets,
    );
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.flag_rounded,
                  color: AppColors.workouts,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Weekly goals', style: text.titleLarge)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The three rings on Home fill up as you reach these.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _GoalStepper(
              icon: Icons.local_fire_department_rounded,
              color: AppColors.workouts,
              label: 'Workouts',
              value: _workouts,
              unit: 'per week',
              step: 1,
              min: 1,
              max: 7,
              onChanged: (v) => setState(() => _workouts = v),
            ),
            const SizedBox(height: AppSpacing.md),
            _GoalStepper(
              icon: Icons.timer_rounded,
              color: AppColors.time,
              label: 'Active time',
              value: _minutes,
              unit: 'min',
              step: 15,
              min: 15,
              max: 1200,
              onChanged: (v) => setState(() => _minutes = v),
            ),
            const SizedBox(height: AppSpacing.md),
            _GoalStepper(
              icon: Icons.layers_rounded,
              color: AppColors.sets,
              label: 'Working sets',
              value: _sets,
              unit: 'sets',
              step: 5,
              min: 5,
              max: 300,
              onChanged: (v) => setState(() => _sets = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _saving ? 'Saving…' : 'Save goals',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStepper extends StatelessWidget {
  const _GoalStepper({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final String unit;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$value',
                        style: AppText.metricM.copyWith(color: color),
                      ),
                      TextSpan(text: ' $unit', style: AppText.unit),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Less',
            icon: const Icon(Icons.remove_rounded),
            onPressed: value - step >= min
                ? () => onChanged(value - step)
                : null,
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.add_rounded),
            onPressed: value + step <= max
                ? () => onChanged(value + step)
                : null,
          ),
        ],
      ),
    );
  }
}
