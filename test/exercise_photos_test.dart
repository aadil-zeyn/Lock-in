import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/seed_exercises.dart';
import 'package:lock_in/core/utils/exercise_photos.dart';

void main() {
  final seedNames = {
    for (final e in seedExercises())
      if (e.name case Value(:final value)) value,
  };

  test('every photo belongs to a built-in exercise', () {
    expect(
      seedNames.containsAll(exercisePhotoBases.keys),
      isTrue,
      reason: '${exercisePhotoBases.keys.toSet().difference(seedNames)}',
    );
  });

  test('both frames of every photo are bundled', () {
    for (final name in exercisePhotoBases.keys) {
      final f = exercisePhotoFrames(name, isCustom: false)!;
      expect(File(f.start).existsSync(), isTrue, reason: f.start);
      expect(File(f.end).existsSync(), isTrue, reason: f.end);
    }
  });

  test('custom exercises and unknown names have no photo', () {
    expect(exercisePhotoFrames('Barbell Curl', isCustom: true), isNull);
    expect(exercisePhotoFrames('My Weird Move', isCustom: false), isNull);
    expect(exercisePhotoFrames('Barbell Curl', isCustom: false), isNotNull);
  });

  test('photos stay small', () {
    final bytes = Directory('assets/exercises')
        .listSync()
        .whereType<File>()
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(bytes, lessThan(2 * 1024 * 1024));
  });
}
