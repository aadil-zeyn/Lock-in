import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../data/food_repository.dart';

/// Add a food entry for [day] (time of day defaults to now), or edit
/// [existing]. Quick entries: only kcal is required.
Future<void> showFoodEntrySheet(
  BuildContext context, {
  required DateTime day,
  Meal? meal,
  FoodEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _FoodEntrySheet(day: day, meal: meal, existing: existing),
  );
}

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
  bool _favourite = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kcal = TextEditingController(text: e?.kcal.toString() ?? '');
    _protein = TextEditingController(
      text: e?.proteinG == null ? '' : _trim(e!.proteinG!),
    );
    _carbs = TextEditingController(
      text: e?.carbsG == null ? '' : _trim(e!.carbsG!),
    );
    _fat = TextEditingController(text: e?.fatG == null ? '' : _trim(e!.fatG!));
    _name = TextEditingController(text: e?.name ?? '');
    _meal = e?.meal ?? widget.meal ?? Meal.forTime(DateTime.now());
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Keeps the chosen day but uses the current clock time, so entries for
  /// a past day still sort in a sensible order.
  DateTime _timestamp() {
    final now = DateTime.now();
    final d = widget.day;
    return DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second);
  }

  Future<void> _save() async {
    final kcal = int.tryParse(_kcal.text);
    double? grams(TextEditingController c) => c.text.trim().isEmpty
        ? null
        : double.tryParse(c.text.replaceAll(',', '.'));
    final protein = grams(_protein);
    final carbs = grams(_carbs);
    final fat = grams(_fat);
    final error = validateFoodValues(kcal, protein);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
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
      );
    } else {
      await repo.addEntry(
        kcal: kcal!,
        meal: _meal,
        at: _timestamp(),
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
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(foodRepositoryProvider).deleteEntry(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasName = _name.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
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
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _protein,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,3}([.,]\d?)?'),
                      ),
                    ],
                    style: AppText.metricM,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      hintText: 'optional',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _GramField(controller: _carbs, label: 'Carbs (g)'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _GramField(controller: _fat, label: 'Fat (g)'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(
                hintText: 'What was it? (optional)',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
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
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _GramField extends StatelessWidget {
  const _GramField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d?)?')),
      ],
      decoration: InputDecoration(labelText: label, hintText: 'optional'),
    );
  }
}
