import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/core/database/database_provider.dart';
import 'package:lock_in/features/food/data/food_catalog.dart';
import 'package:lock_in/features/food/data/food_repository.dart';
import 'package:lock_in/features/food/presentation/food_entry_sheet.dart';

void main() {
  late AppDatabase db;
  late FoodRepository repo;
  final noon = DateTime(2026, 11, 6, 12, 30);
  final puttu = foodCatalog.firstWhere((f) => f.name == 'Puttu');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FoodRepository(db);
  });
  tearDown(() => db.close());

  Future<void> openEditor(WidgetTester tester, FoodEntry entry) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showFoodEntrySheet(context, day: noon, existing: entry),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, Finder f) =>
      tester.widget<TextField>(f).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  testWidgets('changing servings of a built-in food rescales everything', (
    tester,
  ) async {
    final id = await repo.logCatalog(puttu, 2, Meal.breakfast, noon);
    final entry = (await repo.getEntry(id))!;
    await openEditor(tester, entry);

    expect(find.text('Edit food'), findsOneWidget);
    expect(find.text('servings'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pump();

    final fields = find.byType(TextField);
    expect(fieldText(tester, fields.at(0)), 'Puttu × 2½');
    expect(fieldText(tester, fields.at(1)), '${(puttu.kcal * 2.5).round()}');

    await tester.tap(find.text('Dinner'));
    await save(tester);

    final e = (await repo.getEntry(id))!;
    expect(e.name, 'Puttu × 2½');
    expect(e.kcal, (puttu.kcal * 2.5).round());
    expect(e.proteinG, closeTo(puttu.protein * 2.5, 0.051));
    expect(e.meal, Meal.dinner);
    expect(e.loggedAt, noon);
  });

  testWidgets('a quick add scales from the numbers typed', (tester) async {
    final id = await repo.addEntry(
      kcal: 300,
      meal: Meal.lunch,
      at: noon,
      name: 'Mum\'s curry',
      proteinG: 20,
    );
    await openEditor(tester, (await repo.getEntry(id))!);

    final kcal = find.byType(TextField).at(1);
    await tester.enterText(kcal, '400');
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(find.text('×1½'), findsOneWidget);
    expect(fieldText(tester, kcal), '600');
    await save(tester);

    final e = (await repo.getEntry(id))!;
    expect((e.name, e.kcal, e.proteinG), ('Mum\'s curry', 600, 30.0));
  });

  testWidgets('deleting shows Undo, which brings the entry back', (
    tester,
  ) async {
    final id = await repo.addEntry(kcal: 250, meal: Meal.snack, at: noon);
    await openEditor(tester, (await repo.getEntry(id))!);

    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();
    expect(await repo.getEntry(id), isNull);
    expect(find.text('Deleted Quick add'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await repo.getEntry(id))?.kcal, 250);
  });
}
