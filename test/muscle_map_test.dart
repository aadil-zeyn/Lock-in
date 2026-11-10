import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/app/theme/muscle_style.dart';
import 'package:lock_in/core/database/enums.dart';
import 'package:lock_in/core/widgets/muscle_map.dart';

void main() {
  test('every muscle group is drawn on the body diagram', () {
    final drawn = {
      for (final view in BodyView.values)
        for (final p in bodyParts(view))
          if (p.muscle != null) p.muscle!,
    };
    expect(drawn, containsAll(MuscleGroup.values));
  });

  test('shapes stay inside the 100 × 220 design space and the body', () {
    const bounds = Rect.fromLTRB(0, 0, 100, 220);
    final body = bodyOutline.getBounds();
    expect(bounds.contains(body.topLeft), isTrue);
    expect(body.right <= 100 && body.bottom <= 220, isTrue);
    for (final view in BodyView.values) {
      for (final p in bodyParts(view)) {
        final r = p.path.getBounds();
        expect(r.isEmpty, isFalse, reason: '${p.muscle}');
        expect(body.inflate(0.5).contains(r.topLeft), isTrue);
        expect(r.right <= body.right + 0.5, isTrue);
        expect(r.bottom <= body.bottom + 0.5, isTrue);
      }
    }
  });

  test('the figure is symmetric', () {
    final b = bodyOutline.getBounds();
    expect(b.left + b.right, closeTo(100, 0.01));
    for (final view in BodyView.values) {
      for (final p in bodyParts(view)) {
        final r = p.path.getBounds();
        expect(r.left + r.right, closeTo(100, 0.01));
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
