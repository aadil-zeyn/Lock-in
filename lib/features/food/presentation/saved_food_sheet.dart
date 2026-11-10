import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../data/food_repository.dart';
import 'food_fields.dart';

/// Lists the favourites; tap one to fix it, or remove it.
Future<void> showFavouritesManager(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => _FavouritesList(scroll: scroll),
    ),
  );
}

/// Edit a favourite: name, calories, macros. Already-logged entries keep
/// their own values.
Future<void> showSavedFoodSheet(BuildContext context, SavedFood food) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SavedFoodSheet(food: food),
  );
}

class _FavouritesList extends ConsumerWidget {
  const _FavouritesList({required this.scroll});
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedFoodsProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        Text('Favourites', style: text.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tap one to fix its name or numbers.',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        if (saved.isEmpty)
          const EmptyState(
            icon: Icons.star_outline_rounded,
            title: 'No favourites yet',
            message: 'Tick "Save to favourites" when you add a food.',
          ),
        for (final f in saved)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Material(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
                title: Text(f.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    '${f.kcal} kcal',
                    if (f.proteinG != null)
                      '${trimNumber(f.proteinG!)} g protein',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => showSavedFoodSheet(context, f),
              ),
            ),
          ),
      ],
    );
  }
}

class _SavedFoodSheet extends ConsumerStatefulWidget {
  const _SavedFoodSheet({required this.food});
  final SavedFood food;

  @override
  ConsumerState<_SavedFoodSheet> createState() => _SavedFoodSheetState();
}

class _SavedFoodSheetState extends ConsumerState<_SavedFoodSheet> {
  late final _name = TextEditingController(text: widget.food.name);
  late final _kcal = TextEditingController(text: '${widget.food.kcal}');
  late final _protein = TextEditingController(text: _g(widget.food.proteinG));
  late final _carbs = TextEditingController(text: _g(widget.food.carbsG));
  late final _fat = TextEditingController(text: _g(widget.food.fatG));
  String? _error;

  static String _g(double? v) => v == null ? '' : trimNumber(v);

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kcal = int.tryParse(_kcal.text);
    final protein = parseGrams(_protein.text);
    final error = _name.text.trim().isEmpty
        ? 'Give the food a name'
        : validateFoodValues(kcal, protein);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    try {
      await ref
          .read(foodRepositoryProvider)
          .updateSaved(
            widget.food.id,
            name: _name.text,
            kcal: kcal!,
            proteinG: protein,
            carbsG: parseGrams(_carbs.text),
            fatG: parseGrams(_fat.text),
          );
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
      return;
    }
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await ref.read(foodRepositoryProvider).deleteSaved(widget.food.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    void clearError(String _) {
      if (_error != null) setState(() => _error = null);
    }

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
                  icon: Icons.star_rounded,
                  color: AppColors.food,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Edit favourite', style: text.titleLarge)),
                IconButton(
                  tooltip: 'Remove favourite',
                  onPressed: _delete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Name',
                counterText: '',
              ),
              onChanged: clearError,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _kcal,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    style: AppText.metricL,
                    decoration: const InputDecoration(
                      hintText: '0',
                      suffixText: 'kcal',
                      suffixStyle: AppText.unit,
                    ),
                    onChanged: clearError,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: GramField(
                    controller: _protein,
                    label: 'Protein (g)',
                    style: AppText.metricM,
                    onChanged: clearError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: GramField(controller: _carbs, label: 'Carbs (g)'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GramField(controller: _fat, label: 'Fat (g)'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: text.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Food you already logged keeps its old values — edit those '
              'entries separately.',
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Save favourite',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
