import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/features/food/data/food_catalog.dart';

void main() {
  test('every food has sane, self-consistent numbers', () {
    for (final f in foodCatalog) {
      expect(f.kcal, inInclusiveRange(1, 1500), reason: f.name);
      expect(
        f.protein >= 0 && f.carbs >= 0 && f.fat >= 0,
        isTrue,
        reason: f.name,
      );
      // Atwater check: 4 kcal/g protein & carbs, 9 kcal/g fat. Fibre and
      // rounding make it approximate, so allow 25% or 25 kcal.
      final fromMacros = 4 * f.protein + 4 * f.carbs + 9 * f.fat;
      final tolerance = (f.kcal * 0.25).clamp(25, double.infinity);
      expect(
        (fromMacros - f.kcal).abs(),
        lessThanOrEqualTo(tolerance),
        reason:
            '${f.name}: ${f.kcal} kcal vs ${fromMacros.round()} from macros',
      );
    }
  });

  test('names are unique', () {
    final names = foodCatalog.map((f) => f.name.toLowerCase()).toList();
    expect(names.toSet(), hasLength(names.length));
  });

  test('search finds by name, alias, spelling and category', () {
    expect(searchFoods('puttu').first.name, 'Puttu');
    expect(searchFoods('omlete').map((f) => f.name), contains('Omelette'));
    expect(searchFoods('porotta').single.name, 'Kerala parotta');
    expect(searchFoods('meen').length, greaterThanOrEqualTo(2));
    expect(
      searchFoods('', category: FoodCategory.kerala),
      everyElement(
        predicate<CatalogFood>((f) => f.category == FoodCategory.kerala),
      ),
    );
    expect(searchFoods('xyzzy'), isEmpty);
  });
}
