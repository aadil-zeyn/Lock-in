import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/enums.dart';
import 'package:lock_in/core/utils/strength.dart';
import 'package:lock_in/core/utils/units.dart';

void main() {
  group('estimateOneRepMax (Epley)', () {
    test('1 rep returns the weight itself', () {
      expect(estimateOneRepMax(100, 1), 100);
    });
    test('10 reps at 100 kg ≈ 133.3 kg', () {
      expect(estimateOneRepMax(100, 10), closeTo(133.33, 0.01));
    });
    test('outside 1–12 reps is null', () {
      expect(estimateOneRepMax(100, 0), isNull);
      expect(estimateOneRepMax(100, 13), isNull);
      expect(estimateOneRepMax(0, 5), isNull);
    });
  });

  group('setVolume', () {
    test('weight × reps', () => expect(setVolume(22.5, 10), 225));
    test('missing values contribute 0', () {
      expect(setVolume(null, 10), 0);
      expect(setVolume(20, null), 0);
    });
  });

  group('effectiveBodyweightLoad', () {
    test('added weight', () => expect(effectiveBodyweightLoad(80, 10), 90));
    test('assistance', () => expect(effectiveBodyweightLoad(80, -30), 50));
    test('no body weight recorded', () {
      expect(effectiveBodyweightLoad(null, 0), isNull);
    });
  });

  group('units', () {
    test('kg ↔ lb round-trips', () {
      final lb = kgToDisplay(100, WeightUnit.lb);
      expect(lb, closeTo(220.46, 0.01));
      expect(displayToKg(lb, WeightUnit.lb), closeTo(100, 1e-9));
    });
    test('formatNumber trims zeros', () {
      expect(formatNumber(20), '20');
      expect(formatNumber(22.5), '22.5');
      expect(formatNumber(102.25), '102.25');
      expect(formatNumber(102.256), '102.26');
    });
  });
}
