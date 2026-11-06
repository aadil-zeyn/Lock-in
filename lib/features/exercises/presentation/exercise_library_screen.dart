import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../data/exercise_providers.dart';

/// Searchable exercise library. With [archived] it lists archived
/// exercises instead, so they can be opened and restored.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({
    super.key,
    this.archived = false,
    this.pickMode = false,
  });

  final bool archived;

  /// Multi-select for adding to a workout: tiles toggle instead of opening
  /// details, and the screen pops with the chosen exercise ids in order.
  final bool pickMode;

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String _query = '';
  MuscleGroup? _muscle;
  Equipment? _equipment;
  final _picked = <int>{}; // insertion-ordered

  bool get _filtered =>
      _query.trim().isNotEmpty || _muscle != null || _equipment != null;

  @override
  Widget build(BuildContext context) {
    final archived = widget.archived;
    final exercises = ref.watch(
      exerciseListProvider((
        query: _query,
        muscle: _muscle,
        equipment: _equipment,
        archived: archived,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pickMode
              ? 'Add exercises'
              : archived
              ? 'Archived exercises'
              : 'Exercise library',
        ),
        actions: [
          if (!archived && !widget.pickMode)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (_) => context.push(Routes.archivedExercises),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'archived',
                  child: Text('Archived exercises'),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: widget.pickMode
          ? (_picked.isEmpty
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => context.pop(_picked.toList()),
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      'Add ${_picked.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ))
          : archived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(Routes.newExercise),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New exercise',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (!archived) ...[
            _ChipRow(
              children: [
                SelectChip(
                  label: 'All muscles',
                  selected: _muscle == null,
                  onTap: () => setState(() => _muscle = null),
                ),
                for (final m in MuscleGroup.values)
                  SelectChip(
                    label: m.label,
                    color: m.color,
                    selected: _muscle == m,
                    onTap: () =>
                        setState(() => _muscle = _muscle == m ? null : m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChipRow(
              children: [
                SelectChip(
                  label: 'Any equipment',
                  selected: _equipment == null,
                  color: AppColors.textPrimary,
                  onTap: () => setState(() => _equipment = null),
                ),
                for (final eq in Equipment.values)
                  SelectChip(
                    label: eq.label,
                    icon: eq.icon,
                    color: AppColors.textPrimary,
                    selected: _equipment == eq,
                    onTap: () => setState(
                      () => _equipment = _equipment == eq ? null : eq,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: exercises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Couldn\'t load exercises',
                message: '$e',
              ),
              data: (list) {
                if (list.isEmpty) {
                  return archived && !_filtered
                      ? const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Nothing archived',
                          message:
                              'Archived exercises are hidden from the library '
                              'but stay in your history.',
                        )
                      : EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matches',
                          message: archived ? 'Try another name.' : 'Try another name or filter, or create your own.',
                          actionLabel: archived ? null : 'Create exercise',
                          onAction: archived
                              ? null
                              : () => context.push(Routes.newExercise),
                        );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    96 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: list.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: Text(
                          '${list.length} ${list.length == 1 ? 'exercise' : 'exercises'}'
                              .toUpperCase(),
                          style: AppText.overline,
                        ),
                      );
                    }
                    final e = list[i - 1];
                    if (!widget.pickMode) return ExerciseTile(exercise: e);
                    final selected = _picked.contains(e.id);
                    return ExerciseTile(
                      exercise: e,
                      selected: selected,
                      onTap: () => setState(
                        () =>
                            selected ? _picked.remove(e.id) : _picked.add(e.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          for (final c in children)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: c,
            ),
        ],
      ),
    );
  }
}

/// One row in the library: muscle badge, name, muscle · equipment.
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.exercise,
    this.selected,
    this.onTap,
  });
  final Exercise exercise;

  /// Non-null in pick mode: shows a tick box instead of the chevron.
  final bool? selected;

  /// Defaults to opening the exercise's details.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muscle = exercise.primaryMuscle;
    final picked = selected ?? false;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      color: picked
          ? AppColors.accent.withValues(alpha: 0.12)
          : AppColors.surface,
      onTap: onTap ?? () => context.push(Routes.exerciseDetails(exercise.id)),
      child: Row(
        children: [
          IconBadge(
            text: muscle.initials,
            color: muscle.color,
            size: 48,
            circle: false,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      exercise.equipment.icon,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '${muscle.label} · ${exercise.equipment.label}',
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (exercise.isCustom) const _Tag('CUSTOM'),
          if (selected == null)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Semantics(
                checked: picked,
                child: Icon(
                  picked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: picked ? AppColors.accent : AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
