import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/food_repository.dart';
import 'food_entry_sheet.dart';
import 'food_picker_sheet.dart';

String _thousands(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

String dayLabel(DateTime day, DateTime now) {
  final d = dayStart(day), t = dayStart(now);
  if (d == t) return 'Today';
  if (d == t.subtract(const Duration(days: 1))) return 'Yesterday';
  return formatLongDate(d);
}

/// Food tab: one day at a time, quick kcal/protein entries per meal.
class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({super.key});

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  DateTime _day = dayStart(DateTime.now());

  bool get _isToday => _day == dayStart(DateTime.now());

  void _shift(int days) => setState(() {
    final next = _day.add(Duration(days: days));
    if (!next.isAfter(dayStart(DateTime.now()))) _day = dayStart(next);
  });

  Future<void> _logFavourite(SavedFood f) async {
    final now = DateTime.now();
    final at = DateTime(_day.year, _day.month, _day.day, now.hour, now.minute);
    final meal = Meal.forTime(now);
    final repo = ref.read(foodRepositoryProvider);
    final id = await repo.logSaved(f, meal, at);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Added ${f.name} to ${meal.label}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.deleteEntry(id),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(dayFoodProvider(_day)).value ?? const [];
    final saved = ref.watch(savedFoodsProvider).value ?? const [];
    final profile = ref.watch(userProfileProvider).value;
    final totals = totalsFor(entries);
    final text = Theme.of(context).textTheme;

    return TabPage(
      title: 'Food',
      subtitle: dayLabel(_day, DateTime.now()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: _isToday ? null : () => _shift(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      children: [
        const SizedBox(height: AppSpacing.lg),
        FoodRingsCard(
          totals: totals,
          kcalGoal: profile?.dailyKcalGoal ?? 2200,
          proteinGoal: profile?.dailyProteinGoal ?? 140,
          onTap: () => _editGoals(
            profile?.dailyKcalGoal ?? 2200,
            profile?.dailyProteinGoal ?? 140,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Add food',
          icon: Icons.add_rounded,
          onPressed: () => showFoodPicker(context, day: _day),
        ),
        if (saved.isNotEmpty) ...[
          const SectionHeader('Favourites'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: saved.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final f = saved[i];
                return InputChip(
                  label: Text('${f.name} · ${f.kcal}'),
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => _logFavourite(f),
                  onDeleted: () =>
                      ref.read(foodRepositoryProvider).deleteSaved(f.id),
                  deleteButtonTooltipMessage: 'Remove favourite',
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final meal in Meal.values) ...[
          _MealCard(
            meal: meal,
            entries: totals.byMeal[meal]!,
            kcal: totals.kcalFor(meal),
            onAdd: () => showFoodPicker(context, day: _day, meal: meal),
            onOpen: (e) => showFoodEntrySheet(context, day: _day, existing: e),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (entries.isEmpty)
          Text(
            _isToday
                ? 'Tap Add food and search the list — puttu, omelette, biryani…'
                : 'Nothing logged on this day.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }

  Future<void> _editGoals(int kcal, int protein) async {
    final k = TextEditingController(text: '$kcal');
    final p = TextEditingController(text: '$protein');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily targets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: k,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Calories',
                suffixText: 'kcal',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: p,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Protein',
                suffixText: 'g',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              this.context.push(Routes.editProfile);
            },
            child: const Text('Calculate from profile'),
          ),
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
    final newK = int.tryParse(k.text);
    final newP = int.tryParse(p.text);
    k.dispose();
    p.dispose();
    if (ok != true) return;
    await ref
        .read(foodRepositoryProvider)
        .setGoals(
          kcal: newK != null && newK >= 800 && newK <= 10000 ? newK : null,
          protein: newP != null && newP >= 0 && newP <= 500 ? newP : null,
        );
  }
}

/// Calories + protein rings with eaten / target and what's left.
/// Shared with the Home tab.
class FoodRingsCard extends StatelessWidget {
  const FoodRingsCard({
    super.key,
    required this.totals,
    required this.kcalGoal,
    required this.proteinGoal,
    this.onTap,
    this.compact = false,
  });

  final DayTotals totals;
  final int kcalGoal;
  final int proteinGoal;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final left = kcalGoal - totals.kcal;
    final protein = totals.proteinG.round();
    final text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      child: Row(
        children: [
          ActivityRings(
            size: compact ? 84 : 116,
            strokeWidth: compact ? 10 : 13,
            semanticsLabel:
                '${totals.kcal} of $kcalGoal kcal, $protein of $proteinGoal '
                'grams protein',
            rings: [
              RingData(
                progress: kcalGoal == 0 ? 0 : totals.kcal / kcalGoal,
                color: AppColors.food,
              ),
              RingData(
                progress: proteinGoal == 0 ? 0 : protein / proteinGoal,
                color: AppColors.protein,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  left >= 0 ? 'LEFT TODAY' : 'OVER TARGET',
                  style: AppText.overline,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _thousands(left.abs()),
                        style: compact ? AppText.metricM : AppText.metricL,
                      ),
                      const TextSpan(text: ' kcal', style: AppText.unit),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Legend(
                  color: AppColors.food,
                  text:
                      '${_thousands(totals.kcal)} / ${_thousands(kcalGoal)} kcal',
                ),
                const SizedBox(height: 2),
                _Legend(
                  color: AppColors.protein,
                  text: '$protein / $proteinGoal g protein',
                ),
                if (totals.carbsG > 0 || totals.fatG > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Carbs ${totals.carbsG.round()} g · Fat ${totals.fatG.round()} g',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (!compact && onTap != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tap to change targets',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.entries,
    required this.kcal,
    required this.onAdd,
    required this.onOpen,
  });

  final Meal meal;
  final List<FoodEntry> entries;
  final int kcal;
  final VoidCallback onAdd;
  final ValueChanged<FoodEntry> onOpen;

  IconData get _icon => switch (meal) {
    Meal.breakfast => Icons.free_breakfast_rounded,
    Meal.lunch => Icons.lunch_dining_rounded,
    Meal.dinner => Icons.dinner_dining_rounded,
    Meal.snack => Icons.cookie_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(icon: _icon, color: AppColors.food, size: 34),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(meal.label, style: text.titleMedium)),
              if (kcal > 0)
                Text(
                  '${_thousands(kcal)} kcal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              IconButton(
                tooltip: 'Add to ${meal.label}',
                onPressed: onAdd,
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.food,
                ),
              ),
            ],
          ),
          for (final e in entries)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onOpen(e),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  46,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.name.isEmpty ? 'Quick add' : e.name,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: e.name.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (e.proteinG != null)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: Text(
                          '${e.proteinG!.round()} g',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    Text(
                      '${e.kcal}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
