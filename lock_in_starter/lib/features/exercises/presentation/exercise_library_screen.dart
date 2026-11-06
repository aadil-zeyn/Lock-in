import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../data/exercise_providers.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String _query = '';
  MuscleGroup? _muscle;

  @override
  Widget build(BuildContext context) {
    final exercises =
        ref.watch(exerciseListProvider((query: _query, muscle: _muscle)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise library'),
        actions: [
          IconButton(
            tooltip: 'Create exercise',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => showComingSoon(context, 'Custom exercises'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                _chip('All', _muscle == null, () => _muscle = null),
                for (final m in MuscleGroup.values)
                  _chip(m.label, _muscle == m, () => _muscle = m),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: exercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Couldn\'t load exercises',
                message: '$e',
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message: 'Try another name, or create a custom exercise.',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) =>
                          _ExerciseTile(exercise: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback select) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(select),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
      onTap: () => showComingSoon(context, 'Exercise details'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              exercise.primaryMuscle.label.substring(0, 2).toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${exercise.primaryMuscle.label} · ${exercise.equipment.label}',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (exercise.isCustom)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm),
              child: Text('Custom', style: AppText.overline),
            ),
        ],
      ),
    );
  }
}
