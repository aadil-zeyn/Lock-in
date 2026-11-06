import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../data/exercise_providers.dart';
import '../data/exercise_repository.dart';

/// Create a custom exercise, or edit one when [exerciseId] is given.
class ExerciseFormScreen extends ConsumerWidget {
  const ExerciseFormScreen({super.key, this.exerciseId});

  final int? exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = exerciseId;
    if (id == null) return const _ExerciseForm(existing: null);

    final exercise = ref.watch(exerciseProvider(id));
    return exercise.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Couldn\'t load exercise',
          message: '$e',
        ),
      ),
      data: (e) => e == null
          ? Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                icon: Icons.help_outline_rounded,
                title: 'Exercise not found',
                message: 'It may have been removed.',
              ),
            )
          : _ExerciseForm(existing: e),
    );
  }
}

class _ExerciseForm extends ConsumerStatefulWidget {
  const _ExerciseForm({required this.existing});
  final Exercise? existing;

  @override
  ConsumerState<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends ConsumerState<_ExerciseForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameKey = GlobalKey();
  final _primaryKey = GlobalKey();
  final _equipmentKey = GlobalKey();
  late final TextEditingController _name;
  late final TextEditingController _description;

  MuscleGroup? _primary;
  late Set<MuscleGroup> _secondary;
  Equipment? _equipment;
  late TrackingType _tracking;

  /// Once the user picks a tracking type we stop auto-suggesting one.
  bool _trackingTouched = false;
  String? _nameError;
  bool _saving = false;
  bool _showMissing = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _primary = e?.primaryMuscle;
    _secondary = e?.secondaryMuscleList.toSet() ?? {};
    _equipment = e?.equipment;
    _tracking = e?.trackingType ?? TrackingType.weightReps;
    _trackingTouched = e != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _dirty {
    final e = widget.existing;
    if (e == null) {
      return _name.text.trim().isNotEmpty ||
          _description.text.trim().isNotEmpty ||
          _primary != null ||
          _secondary.isNotEmpty ||
          _equipment != null;
    }
    final original = ExerciseDraft.fromExercise(e);
    return normalizeExerciseName(_name.text) != original.cleanName ||
        (_description.text.trim()) != (original.cleanDescription ?? '') ||
        _primary != original.primaryMuscle ||
        _equipment != original.equipment ||
        _tracking != original.trackingType ||
        encodeMuscles(_secondary.where((m) => m != _primary)) !=
            original.encodedSecondary;
  }

  void _pickEquipment(Equipment eq) {
    setState(() {
      _equipment = eq;
      // Sensible default the user can still override.
      if (!_trackingTouched) {
        _tracking = switch (eq) {
          Equipment.bodyweight => TrackingType.bodyweightReps,
          Equipment.band => TrackingType.bandReps,
          _ => TrackingType.weightReps,
        };
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _showMissing = true;
      _nameError = null;
    });
    final formOk = _formKey.currentState!.validate();
    if (!formOk || _primary == null || _equipment == null) {
      // Bring the first problem into view; errors may be off-screen.
      final target = !formOk
          ? _nameKey
          : (_primary == null ? _primaryKey : _equipmentKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = target.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.1,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
      return;
    }

    final draft = ExerciseDraft(
      name: _name.text,
      primaryMuscle: _primary!,
      secondaryMuscles: _secondary,
      equipment: _equipment!,
      trackingType: _tracking,
      description: _description.text,
    );

    setState(() => _saving = true);
    final repo = ref.read(exerciseRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.update(widget.existing!.id, draft);
        if (mounted) context.pop();
      } else {
        final id = await repo.create(draft);
        if (mounted) context.pushReplacement(Routes.exerciseDetails(id));
      }
    } on DuplicateExerciseNameException {
      setState(
        () => _nameError = 'You already have an exercise with this name',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What you\'ve entered won\'t be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final previewColor = _primary?.color ?? AppColors.textTertiary;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit exercise' : 'New exercise')),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          child: PrimaryButton(
            label: _saving
                ? 'Saving…'
                : (_isEdit ? 'Save changes' : 'Create exercise'),
            icon: Icons.check_rounded,
            onPressed: _saving ? null : _save,
          ),
        ),
        body: Form(
          key: _formKey,
          // Not a lazy ListView: every field must exist so we can scroll to
          // the first error.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live preview.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: AppGradients.tint(previewColor),
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: MuscleMap(
                    primary: _primary,
                    secondary: _secondary.where((m) => m != _primary).toList(),
                    height: 150,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  key: _nameKey,
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: exerciseNameMaxLength,
                  autofocus: !_isEdit,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Landmine Press',
                    errorText: _nameError,
                    counterText: '',
                  ),
                  validator: (v) => validateExerciseName(v ?? ''),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                    setState(() {}); // refresh dirty state
                  },
                ),
                _Label(
                  'Primary muscle',
                  key: _primaryKey,
                  error: _showMissing && _primary == null
                      ? 'Pick the main muscle worked'
                      : null,
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final m in MuscleGroup.values)
                      SelectChip(
                        label: m.label,
                        color: m.color,
                        selected: _primary == m,
                        onTap: () => setState(() {
                          _primary = m;
                          _secondary.remove(m);
                        }),
                      ),
                  ],
                ),
                const _Label('Secondary muscles', optional: true),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final m in MuscleGroup.values)
                      SelectChip(
                        label: m.label,
                        color: m.color.withValues(alpha: 0.7),
                        selected: _secondary.contains(m),
                        enabled: m != _primary,
                        onTap: () => setState(
                          () => _secondary.contains(m)
                              ? _secondary.remove(m)
                              : _secondary.add(m),
                        ),
                      ),
                  ],
                ),
                _Label(
                  'Equipment',
                  key: _equipmentKey,
                  error: _showMissing && _equipment == null
                      ? 'Pick the equipment used'
                      : null,
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final eq in Equipment.values)
                      SelectChip(
                        label: eq.label,
                        icon: eq.icon,
                        color: AppColors.volume,
                        selected: _equipment == eq,
                        onTap: () => _pickEquipment(eq),
                      ),
                  ],
                ),
                const _Label('How do you log it?'),
                for (final t in TrackingType.values) ...[
                  _TrackingOption(
                    type: t,
                    selected: _tracking == t,
                    onTap: () => setState(() {
                      _tracking = t;
                      _trackingTouched = true;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const _Label('Notes', optional: true),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Setup, cues, seat height…',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Renaming won\'t change past workouts — they keep the name '
                    'they were logged with.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {super.key, this.optional = false, this.error});
  final String text;
  final bool optional;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: text, style: theme.titleMedium),
                if (optional)
                  TextSpan(
                    text: '  optional',
                    style: theme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  error!,
                  style: theme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingOption extends StatelessWidget {
  const _TrackingOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final TrackingType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(
                color: selected ? AppColors.time : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                IconBadge(icon: type.icon, color: AppColors.time, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        type.hint,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.time : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
