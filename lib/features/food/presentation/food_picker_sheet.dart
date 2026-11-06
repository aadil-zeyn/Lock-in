import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../data/food_catalog.dart';
import '../data/food_repository.dart';
import 'food_entry_sheet.dart';

/// Search the built-in food list, pick servings, log it. "Quick add"
/// falls back to typing calories by hand.
Future<void> showFoodPicker(
  BuildContext context, {
  required DateTime day,
  Meal? meal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) =>
          _FoodPicker(day: day, meal: meal, scroll: scroll),
    ),
  );
}

class _FoodPicker extends ConsumerStatefulWidget {
  const _FoodPicker({required this.day, required this.scroll, this.meal});
  final DateTime day;
  final Meal? meal;
  final ScrollController scroll;

  @override
  ConsumerState<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends ConsumerState<_FoodPicker> {
  String _query = '';
  FoodCategory? _category;
  CatalogFood? _picked;
  double _servings = 1;
  late Meal _meal = widget.meal ?? Meal.forTime(DateTime.now());

  DateTime _timestamp() {
    final now = DateTime.now();
    final d = widget.day;
    return DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second);
  }

  Future<void> _add() async {
    final food = _picked!;
    await ref
        .read(foodRepositoryProvider)
        .logCatalog(food, _servings, _meal, _timestamp());
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _picked == null ? _buildSearch(context) : _buildPortion(context);
  }

  Widget _buildSearch(BuildContext context) {
    final results = searchFoods(_query, category: _category);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Add to ${_meal.label}', style: text.titleLarge),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showFoodEntrySheet(context, day: widget.day, meal: _meal);
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Quick add'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search: puttu, omelette, biryani…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            children: [
              for (final c in [null, ...FoodCategory.values])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: SelectChip(
                    label: c?.label ?? 'All',
                    selected: _category == c,
                    color: AppColors.food,
                    onTap: () => setState(() => _category = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Not in the list',
                  message: 'Use Quick add to type the calories yourself.',
                  actionLabel: 'Quick add',
                  onAction: () {
                    Navigator.pop(context);
                    showFoodEntrySheet(context, day: widget.day, meal: _meal);
                  },
                )
              : ListView.separated(
                  controller: widget.scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.sm,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  itemCount: results.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final f = results[i];
                    return Material(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                        onTap: () => setState(() {
                          _picked = f;
                          _servings = 1;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.name, style: text.titleSmall),
                                    Text(
                                      '${f.portion} · ${f.protein.round()} g protein',
                                      style: text.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${f.kcal}',
                                style: AppText.metricM.copyWith(fontSize: 18),
                              ),
                              const Text(' kcal', style: AppText.unit),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPortion(BuildContext context) {
    final f = _picked!;
    final s = _servings;
    final text = Theme.of(context).textTheme;
    String g(double v) => '${(v * s).toStringAsFixed(v * s < 10 ? 1 : 0)} g';

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to the list',
              onPressed: () => setState(() => _picked = null),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(child: Text(f.name, style: text.titleLarge)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxl + AppSpacing.lg),
          child: Text(
            '1 serving = ${f.portion}',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundButton(
              icon: Icons.remove_rounded,
              label: 'Less',
              onTap: s <= 0.5 ? null : () => setState(() => _servings -= 0.5),
            ),
            SizedBox(
              width: 140,
              child: Column(
                children: [
                  Text(
                    formatServings(s),
                    textAlign: TextAlign.center,
                    style: AppText.metricXL,
                  ),
                  Text(s == 1 ? 'serving' : 'servings', style: AppText.unit),
                ],
              ),
            ),
            _RoundButton(
              icon: Icons.add_rounded,
              label: 'More',
              onTap: s >= 10 ? null : () => setState(() => _servings += 0.5),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          color: AppColors.surfaceHigh,
          child: Row(
            children: [
              _Macro(
                label: 'Calories',
                value: '${(f.kcal * s).round()}',
                color: AppColors.food,
              ),
              _Macro(
                label: 'Protein',
                value: g(f.protein),
                color: AppColors.protein,
              ),
              _Macro(label: 'Carbs', value: g(f.carbs), color: AppColors.time),
              _Macro(label: 'Fat', value: g(f.fat), color: AppColors.records),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Approximate values for a typical recipe. Adjust servings if your '
          'portion was bigger or smaller.',
          style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Add ${catalogEntryName(f, s)}',
          icon: Icons.check_rounded,
          onPressed: _add,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: AppColors.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              icon,
              color: onTap == null
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
