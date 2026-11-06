import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/rest_timer.dart';
import '../data/workout_repository.dart';
import 'set_row.dart';
import 'workout_actions.dart';

/// Full-screen logger for the workout in progress.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeWorkoutProvider);
    final active = activeAsync.value;
    if (active == null) {
      return Scaffold(
        appBar: AppBar(),
        body: activeAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'No workout in progress',
                message: 'Start one and your sets are saved as you go.',
                actionLabel: 'Start workout',
                onAction: () => ref.read(workoutRepositoryProvider).start(),
              ),
      );
    }
    return WorkoutEditor(workoutId: active.id);
  }
}

/// Logs a live workout, or with [editing] corrects a finished one
/// (Save instead of Finish, editable date & duration, no rest timer).
class WorkoutEditor extends ConsumerWidget {
  const WorkoutEditor({
    super.key,
    required this.workoutId,
    this.editing = false,
  });
  final int workoutId;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId)).value;
    final profile = ref.watch(userProfileProvider).value;
    final unit = profile?.weightUnit ?? WeightUnit.kg;
    final restSeconds = profile?.restTimerSeconds ?? 90;
    final repo = ref.read(workoutRepositoryProvider);

    if (detail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final w = detail.workout;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _rename(context, repo, w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(w.name, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => switch (v) {
              'rename' => _rename(context, repo, w),
              'timing' => _editTiming(context, repo, w),
              _ => _discard(context, ref, w),
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              if (editing)
                const PopupMenuItem(
                  value: 'timing',
                  child: Text('Change date & duration'),
                )
              else
                const PopupMenuItem(
                  value: 'discard',
                  child: Text(
                    'Discard workout',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!editing) const _RestBar(),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Add exercise',
                      icon: Icons.add_rounded,
                      onPressed: () => _addExercises(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: editing
                        ? PrimaryButton(
                            label: 'Save',
                            icon: Icons.check_rounded,
                            onPressed: () async {
                              await repo.saveEdits(workoutId);
                              if (context.mounted) context.pop();
                            },
                          )
                        : PrimaryButton(
                            label: 'Finish',
                            icon: Icons.flag_rounded,
                            onPressed: () => _finish(context, ref, detail),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          if (editing)
            _EditHeader(workout: w, onTap: () => _editTiming(context, repo, w))
          else
            _Header(detail: detail, unit: unit),
          const SizedBox(height: AppSpacing.md),
          if (detail.exercises.isEmpty)
            EmptyState(
              compact: true,
              icon: Icons.playlist_add_rounded,
              title: 'Add your first exercise',
              message:
                  'Pick from the library. Last time\'s numbers fill in '
                  'for you.',
              actionLabel: 'Add exercise',
              onAction: () => _addExercises(context, ref),
            ),
          for (var i = 0; i < detail.exercises.length; i++) ...[
            _ExerciseCard(
              key: ValueKey(detail.exercises[i].entry.id),
              item: detail.exercises[i],
              workoutId: workoutId,
              unit: unit,
              isFirst: i == 0,
              isLast: i == detail.exercises.length - 1,
              onSetCompleted: editing
                  ? () {}
                  : () => ref
                        .read(restTimerProvider.notifier)
                        .start(Duration(seconds: restSeconds)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Future<void> _addExercises(BuildContext context, WidgetRef ref) async {
    final ids = await context.push<List<int>>(Routes.pickExercises);
    if (ids == null || ids.isEmpty) return;
    final db = ref.read(databaseProvider);
    final repo = ref.read(workoutRepositoryProvider);
    for (final id in ids) {
      final e = await (db.select(
        db.exercises,
      )..where((x) => x.id.equals(id))).getSingle();
      await repo.addExercise(workoutId, e);
    }
  }

  Future<void> _rename(
    BuildContext context,
    WorkoutRepository repo,
    Workout w,
  ) async {
    final controller = TextEditingController(text: w.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await repo.rename(w.id, name);
  }

  /// Date, start time and duration of a past workout.
  Future<void> _editTiming(
    BuildContext context,
    WorkoutRepository repo,
    Workout w,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: w.startedAt,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: 'Workout date',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(w.startedAt),
      helpText: 'Start time',
    );
    if (time == null || !context.mounted) return;
    final minutes = TextEditingController(
      text: (w.durationSeconds ?? 0) == 0 ? '' : '${w.durationSeconds! ~/ 60}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duration'),
        content: TextField(
          controller: minutes,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'minutes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final mins = int.tryParse(minutes.text) ?? 0;
    minutes.dispose();
    if (ok != true) return;
    await repo.setTiming(
      w.id,
      startedAt: DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
      duration: Duration(minutes: mins.clamp(0, 600)),
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, Workout w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this workout?'),
        content: const Text(
          'Everything logged in this session is deleted. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep logging'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(restTimerProvider.notifier).stop();
    await ref.read(workoutRepositoryProvider).discard(w.id);
    if (context.mounted) context.pop();
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    WorkoutDetail detail,
  ) async {
    if (detail.completedSets == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Tick at least one set first, or discard the workout from the ⋮ menu.',
            ),
          ),
        );
      return;
    }
    final unticked = detail.totalSets - detail.completedSets;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish workout?'),
        content: Text(
          unticked == 0
              ? 'All ${detail.completedSets} sets are done. Nice work.'
              : '${detail.completedSets} sets done, $unticked not ticked. '
                    'Unticked sets with numbers are kept but don\'t count '
                    'toward volume or records; empty ones are removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(restTimerProvider.notifier).stop();
    HapticFeedback.heavyImpact();
    await ref.read(workoutRepositoryProvider).finish(workoutId);
    if (context.mounted) {
      context.pushReplacement(Routes.workoutSummary(workoutId));
    }
  }
}

/// Editing a finished workout: when it was and how long, tap to change.
class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.workout, required this.onTap});
  final Workout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    final mins = (w.durationSeconds ?? 0) ~/ 60;
    final t = TimeOfDay.fromDateTime(w.startedAt).format(context);
    final length = mins == 0
        ? 'no duration'
        : formatDuration(Duration(minutes: mins));
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.edit_calendar_rounded,
            color: AppColors.time,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EDITING PAST WORKOUT', style: AppText.overline),
                const SizedBox(height: 2),
                Text(
                  '${formatLongDate(w.startedAt)} ${w.startedAt.year} · $t · $length',
                  style: Theme.of(context).textTheme.titleSmall,
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

/// Live clock, sets done and volume.
class _Header extends StatefulWidget {
  const _Header({required this.detail, required this.unit});
  final WorkoutDetail detail;
  final WeightUnit unit;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final elapsed = DateTime.now().difference(d.workout.startedAt);
    final total = d.totalSets;
    final progress = total == 0 ? 0.0 : d.completedSets / total;
    final volume = kgToDisplay(d.volumeKg, widget.unit);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          ActivityRings(
            size: 76,
            strokeWidth: 9,
            semanticsLabel: '${d.completedSets} of $total sets done',
            rings: [RingData(progress: progress, color: AppColors.sets)],
            center: Text(
              '${d.completedSets}/$total',
              style: AppText.unit.copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ELAPSED', style: AppText.overline),
                Text(
                  formatClock(elapsed),
                  style: AppText.metricL.copyWith(color: AppColors.time),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('VOLUME', style: AppText.overline),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatNumber(volume.roundToDouble()),
                      style: AppText.metricM.copyWith(color: AppColors.volume),
                    ),
                    TextSpan(
                      text: ' ${unitLabel(widget.unit)}',
                      style: AppText.unit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    super.key,
    required this.item,
    required this.workoutId,
    required this.unit,
    required this.isFirst,
    required this.isLast,
    required this.onSetCompleted,
  });

  final WorkoutExerciseDetail item;
  final int workoutId;
  final WeightUnit unit;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onSetCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final e = item.exercise;
    final tracking = e.trackingType;
    final previous =
        ref
            .watch(
              lastPerformanceProvider((exerciseId: e.id, workoutId: workoutId)),
            )
            .value ??
        const <PreviousSet>[];
    final repo = ref.read(workoutRepositoryProvider);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                text: e.primaryMuscle.initials,
                color: e.primaryMuscle.color,
                size: 40,
                circle: false,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: text.titleMedium),
                    Text(
                      previous.isEmpty
                          ? 'First time — set your baseline'
                          : 'Last: ${previous.map((p) => describePrevious(p, tracking, unit)).join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Exercise options',
                onSelected: (v) async {
                  switch (v) {
                    case 'up':
                      await repo.moveExercise(item.entry.id, -1);
                    case 'down':
                      await repo.moveExercise(item.entry.id, 1);
                    case 'remove':
                      await _remove(context, repo);
                  }
                },
                itemBuilder: (context) => [
                  if (!isFirst)
                    const PopupMenuItem(value: 'up', child: Text('Move up')),
                  if (!isLast)
                    const PopupMenuItem(
                      value: 'down',
                      child: Text('Move down'),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove exercise',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SetHeader(tracking: tracking, unit: unit),
          for (var i = 0; i < item.sets.length; i++)
            SetRow(
              key: ValueKey(item.sets[i].id),
              set: item.sets[i],
              tracking: tracking,
              unit: unit,
              previous: i < previous.length ? previous[i] : null,
              onCompleted: onSetCompleted,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                repo.addSet(item.entry.id);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add set'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WorkoutRepository repo) async {
    final done = item.sets.where((s) => s.isCompleted).length;
    if (done > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove ${item.name}?'),
          content: Text(
            '$done completed ${done == 1 ? 'set' : 'sets'} will be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Remove',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await repo.removeExercise(item.entry.id);
  }
}

/// Countdown shown after a set is ticked. Hidden when no rest is running.
class _RestBar extends ConsumerStatefulWidget {
  const _RestBar();

  @override
  ConsumerState<_RestBar> createState() => _RestBarState();
}

class _RestBarState extends ConsumerState<_RestBar> {
  Timer? _tick;
  bool _buzzed = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final rest = ref.read(restTimerProvider);
      if (rest == null) return;
      final left = rest.remaining(DateTime.now());
      if (left == Duration.zero && !_buzzed) {
        _buzzed = true;
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && ref.read(restTimerProvider) == rest) {
            ref.read(restTimerProvider.notifier).stop();
          }
        });
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rest = ref.watch(restTimerProvider);
    if (rest == null) {
      _buzzed = false;
      return const SizedBox.shrink();
    }
    final left = rest.remaining(DateTime.now());
    final done = left == Duration.zero;
    final progress = rest.total.inMilliseconds == 0
        ? 0.0
        : 1 - left.inMilliseconds / rest.total.inMilliseconds;
    final timer = ref.read(restTimerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        color: AppColors.surfaceHigh,
        child: Row(
          children: [
            ActivityRings(
              size: 40,
              strokeWidth: 5,
              rings: [RingData(progress: progress, color: AppColors.time)],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                done ? 'Rest done — next set' : 'Rest ${formatClock(left)}',
                style: AppText.metricM.copyWith(
                  fontSize: 18,
                  color: done ? AppColors.sets : AppColors.textPrimary,
                ),
              ),
            ),
            if (!done) ...[
              TextButton(
                onPressed: () => timer.adjust(const Duration(seconds: -15)),
                child: const Text('−15s'),
              ),
              TextButton(
                onPressed: () => timer.adjust(const Duration(seconds: 15)),
                child: const Text('+15s'),
              ),
            ],
            IconButton(
              tooltip: 'Stop rest timer',
              onPressed: timer.stop,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
