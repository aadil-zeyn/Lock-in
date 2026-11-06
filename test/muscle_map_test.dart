import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/app/theme/muscle_style.dart';
import 'package:lock_in/core/database/enums.dart';
import 'package:lock_in/core/widgets/muscle_map.dart';

void main() {
  test('every muscle group is drawn on the body diagram', () {
    final drawn = {
      for (final view in BodyView.values)
        for (final r in bodyRegions(view))
          if (r.muscle != null) r.muscle!,
    };
    expect(drawn, containsAll(MuscleGroup.values));
  });

  test('regions stay inside the 100 × 220 design space', () {
    const bounds = Rect.fromLTRB(0, 0, 100, 220);
    for (final view in BodyView.values) {
      for (final r in bodyRegions(view)) {
        expect(bounds.contains(r.rect.topLeft), isTrue, reason: '$r');
        expect(r.rect.right <= 100 && r.rect.bottom <= 220, isTrue);
      }
    }
  });

  test('every muscle group belongs to a colour region', () {
    for (final m in MuscleGroup.values) {
      expect(MuscleRegion.values, contains(m.region));
    }
  });

  testWidgets('diagram announces highlighted muscles to screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MuscleMap(
            primary: MuscleGroup.chest,
            secondary: [MuscleGroup.triceps],
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Body diagram highlighting Chest, Triceps'),
      findsOneWidget,
    );
  });
}
