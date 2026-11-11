import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../data/food_catalog.dart';
import '../data/food_repository.dart';
import 'food_fields.dart';
import 'food_picker_sheet.dart';

/// What the sheet did, so the caller can show the right snackbar.
sealed class _Outcome {
  const _Outcome();
}

class _Saved extends _Outcome {
  const _Saved(this.at);
  final DateTime at;
}

class _Deleted extends _Outcome {
  const _Deleted(this.entry);
  final FoodEntry entry;
}

class _ChangeFood extends _Outcome {
  const _ChangeFood();
}

/// Add a food entry for [day] (time of day defaults to now), or edit
/// [existing]. Quick entries: only kcal is required.
///
/// Editing can change everything: the food itself (pick another from the
/// list), portion, calories and macros, name, meal, day and time. Deleting
/// offers Undo.
Future<void> showFoodEntrySheet(
  BuildContext context, {
  required DateTime day,
  Meal? meal,
  FoodEntry? existing,
}) async {
  final repo = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(foodRepositoryProvider);
  final outcome = await showModalBottomSheet<_Outcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _FoodEntrySheet(day: day, meal: meal, existing: existing),
  );
  if (outcome == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);

  switch (outcome) {
    case _Deleted(:final entry):
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Deleted ${foodEntryLabel(entry)}'),
            // Actions make snackbars stick by default; let it time out.
            persist: false,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => repo.restoreEntry(entry),
            ),
          ),
        );
    case _ChangeFood():
      await showFoodPicker(
        context,
        day: existing!.loggedAt,
        meal: existing.meal,
        replacing: existing,
      );
    case _Saved(:final at):
      // The entry left the day on screen — say where it went.
      if (dayStart(at) != dayStart(day)) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Saved to ${dayLabel(at, DateTime.now())}')),
          );
      }
  }
}

/// Name shown for an entry in lists and messages.
String foodEntryLabel(FoodEntry e) => e.name.isEmpty ? 'Quick add' : e.name;

class _FoodEntrySheet extends ConsumerStatefulWidget {
  const _FoodEntrySheet({required this.day, this.meal, this.existing});
  final DateTime day;
  final Meal? meal;
  final FoodEntry? existing;

  @override
  ConsumerState<_FoodEntrySheet> createState() => _FoodEntrySheetState();
}

class _FoodEntrySheetState extends ConsumerState<_FoodEntrySheet> {
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _name;
  late Meal _meal;
  late DateTime _at;
  bool _favourite = false;
  String? _error;
  bool _saving = false;

  /// Built-in food the entry came from (recognised by its name), if any.
  CatalogFood? _catalogFood;

  /// Portion as a multiple: catalogue servings, or 1 = "as logged".
  double _servings = 1;

  /// Values the portion stepper scales from, and the servings they were
  /// at. Reset whenever a number is typed by hand.
  double _baseServings = 1;
  int? _baseKcal;
  double? _baseProtein, _baseCarbs, _baseFat;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    String g(double? v) => v == null ? '' : trimNumber(v);
    _kcal = TextEditingController(text: e?.kcal.toString() ?? '');
    _protein = TextEditingController(text: g(e?.proteinG));
    _carbs = TextEditingController(text: g(e?.carbsG));
    _fat = TextEditingController(text: g(e?.fatG));
    _name = TextEditingController(text: e?.name ?? '');
    _meal = e?.meal ?? widget.meal ?? Meal.forTime(DateTime.now());
    _at = e?.loggedAt ?? _timestampFor(widget.day);
    if (e != null) {
      final portion = catalogPortionFor(e.name);
      _catalogFood = portion?.food;
      _servings = portion?.servings ?? 1;
      _rebase();
    }
  }

  /// Keeps the chosen day but uses the current clock time, so entries for
  /// a past day still sort in a sensible order.
  static DateTime _timestampFor(DateTime d) {
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second);
  }

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _name.dispose();
    super.dispose();
  }

  void _rebase() {
    _baseServings = _servings;
    _baseKcal = int.tryParse(_kcal.text);
    _baseProtein = parseGrams(_protein.text);
    _baseCarbs = parseGrams(_carbs.text);
    _baseFat = parseGrams(_fat.text);
  }

  void _onNumberTyped() {
    _rebase();
    if (_error != null) setState(() => _error = null);
  }

  void _setServings(double s) {
    final f = s / _baseServings;
    String g(double? v) =>
        v == null ? '' : trimNumber(double.parse((v * f).toStringAsFixed(1)));
    setState(() {
      _servings = s;
      if (_baseKcal != null) _kcal.text = '${(_baseKcal! * f).round()}';
      _protein.text = g(_baseProtein);
      _carbs.text = g(_baseCarbs);
      _fat.text = g(_baseFat);
      if (_catalogFood != null) {
        _name.text = catalogEntryName(_catalogFood!, s);
      }
      _error = null;
    });
  }

  double get _lessServings =>
      _servings > 1 ? _servings - 0.5 : _servings - 0.25;
  double get _moreServings =>
      _servings < 1 ? _servings + 0.25 : _servings + 0.5;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _at.isAfter(now) ? now : _at,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Day eaten',
    );
    if (picked == null) return;
    setState(() {
      _at = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _at.hour,
        _at.minute,
        _at.second,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
      helpText: 'Time eaten',
    );
    if (picked == null) return;
    setState(() {
      _at = DateTime(_at.year, _at.month, _at.day, picked.hour, picked.minute);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final kcal = int.tryParse(_kcal.text);
    final protein = parseGrams(_protein.text);
    final carbs = parseGrams(_carbs.text);
    final fat = parseGrams(_fat.text);
    final error = validateFoodValues(kcal, protein);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(foodRepositoryProvider);
    if (_isEdit) {
      await repo.updateEntry(
        widget.existing!.id,
        kcal: kcal!,
        meal: _meal,
        name: _name.text,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        at: _at,
      );
    } else {
      await repo.addEntry(
        kcal: kcal!,
        meal: _meal,
        at: _at,
        name: _name.text,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      );
    }
    if (_favourite && _name.text.trim().isNotEmpty) {
      await repo.saveFood(_name.text, kcal, protein, carbsG: carbs, fatG: fat);
    }
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context, _Saved(_at));
  }

  Future<void> _delete() async {
    final entry = widget.existing!;
    await ref.read(foodRepositoryProvider).deleteEntry(entry.id);
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context, _Deleted(entry));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasName = _name.text.trim().isNotEmpty;

    final nameField = TextField(
      controller: _name,
      textCapitalization: TextCapitalization.sentences,
      maxLength: 80,
      decoration: InputDecoration(
        labelText: _isEdit ? 'Food' : null,
        hintText: 'What was it? (optional)',
        counterText: '',
      ),
      onChanged: (v) => setState(() {
        // Once renamed by hand, the portion stepper leaves the name alone.
        if (_catalogFood != null) _catalogFood = catalogPortionFor(v)?.food;
      }),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
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
                  icon: Icons.restaurant_rounded,
                  color: AppColors.food,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _isEdit ? 'Edit food' : 'Add food',
                    style: text.titleLarge,
                  ),
                ),
                if (_isEdit)
                  IconButton(
                    tooltip: 'Delete entry',
                    onPressed: _delete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.danger,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isEdit) ...[
              nameField,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, const _ChangeFood()),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Pick a different food'),
                ),
              ),
              _PortionStepper(
                servings: _servings,
                food: _catalogFood,
                onLess: _lessServings < 0.25
                    ? null
                    : () => _setServings(_lessServings),
                onMore: _moreServings > 20
                    ? null
                    : () => _setServings(_moreServings),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _kcal,
                    autofocus: !_isEdit,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    style: AppText.metricL,
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'kcal',
                      suffixStyle: AppText.unit,
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                    onChanged: (_) => _onNumberTyped(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: GramField(
                    controller: _protein,
                    label: 'Protein (g)',
                    style: AppText.metricM,
                    onChanged: (_) => _onNumberTyped(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: GramField(
                    controller: _carbs,
                    label: 'Carbs (g)',
                    onChanged: (_) => _onNumberTyped(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GramField(
                    controller: _fat,
                    label: 'Fat (g)',
                    onChanged: (_) => _onNumberTyped(),
                  ),
                ),
              ],
            ),
            if (!_isEdit) ...[const SizedBox(height: AppSpacing.md), nameField],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in Meal.values)
                  SelectChip(
                    label: m.label,
                    selected: _meal == m,
                    color: AppColors.food,
                    onTap: () => setState(() => _meal = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _PickTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Day',
                    value: dayLabel(_at, DateTime.now()),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PickTile(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: TimeOfDay.fromDateTime(_at).format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            if (hasName) ...[
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _favourite,
                onChanged: (v) => setState(() => _favourite = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Save to favourites for one-tap logging'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: _isEdit ? 'Save changes' : 'Add',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// "− 1½ servings +" for fixing how much was eaten. Scales calories and
/// macros together.
class _PortionStepper extends StatelessWidget {
  const _PortionStepper({
    required this.servings,
    required this.food,
    required this.onLess,
    required this.onMore,
  });

  final double servings;
  final CatalogFood? food;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final f = food;
    final value = f != null
        ? formatServings(servings)
        : '×${formatServings(servings)}';
    final unit = f != null
        ? (servings == 1 ? 'serving' : 'servings')
        : 'of what you logged';
    return AppCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Less',
                onPressed: onLess,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label: 'Portion $value $unit',
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text(value, style: AppText.metricM),
                        Text(unit, style: AppText.unit),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: onMore,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          Text(
            f != null
                ? '1 serving = ${f.portion} · ${f.kcal} kcal'
                : 'Ate more or less? Calories and macros scale together.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Change ${label.toLowerCase()}, $value',
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
