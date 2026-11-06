import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/history_import/data/history_csv.dart';
import 'package:lock_in/features/history_import/data/history_importer.dart';

/// Same header and shape the History Logger page produces.
const header =
    'date,workout,duration_min,exercise,primary_muscle,equipment,tracking,set,set_type,weight,unit,reps,seconds';

const sample =
    '''
$header
2026-10-12,Push Day,65,Barbell Bench Press,,,,1,warmup,40,kg,10,
2026-10-12,Push Day,65,Barbell Bench Press,,,,2,normal,60,kg,8,
2026-10-12,Push Day,65,Barbell Bench Press,,,,3,normal,60,kg,7,
2026-10-12,Push Day,65,"Landmine Press, single arm",shoulders,barbell,weightReps,1,normal,20,kg,10,
2026-10-12,Push Day,65,Plank,,,,1,normal,,,,60
2026-10-14,Pull Day,,Assisted Pull-up,,,,1,normal,20,kg,8,
2026-10-14,Pull Day,,Dumbbell Row,,,,1,normal,50,lb,12,
''';

void main() {
  group('parseHistoryCsv', () {
    test('groups rows into workouts and exercises', () {
      final p = parseHistoryCsv(sample);
      expect(p.problems, isEmpty);
      expect(p.workouts, hasLength(2));
      final push = p.workouts.first;
      expect(push.name, 'Push Day');
      expect(push.date, DateTime(2026, 10, 12));
      expect(push.durationMin, 65);
      expect(push.exercises.map((e) => e.name), [
        'Barbell Bench Press',
        'Landmine Press, single arm',
        'Plank',
      ]);
      expect(push.exercises.first.rawSets.first.type, SetType.warmup);
      expect(p.setCount, 7);
    });

    test('reads quoted names and new-exercise details', () {
      final landmine = parseHistoryCsv(sample).workouts.first.exercises[1];
      expect(landmine.spec?.muscle, MuscleGroup.shoulders);
      expect(landmine.spec?.equipment, Equipment.barbell);
    });

    test('converts pounds to kilograms', () {
      final row = parseHistoryCsv(sample).workouts.last.exercises.last;
      expect(row.rawSets.single.weightKg, closeTo(22.68, 0.01));
    });

    test('accepts CRLF line endings and columns in any order', () {
      const text = 'reps,exercise,date\r\n10,Deadlift,2026-09-01\r\n';
      final p = parseHistoryCsv(text);
      expect(p.problems, isEmpty);
      expect(p.workouts.single.name, 'Workout');
      expect(p.workouts.single.exercises.single.rawSets.single.reps, 10);
    });

    test('reports bad lines and keeps the good ones', () {
      const text =
          '''
$header
2026-13-40,Push,,Deadlift,,,,1,normal,100,kg,5,
2026-10-01,Push,,Deadlift,,,,1,normal,abc,kg,5,
2026-10-01,Push,,Deadlift,,,,1,normal,100,kg,,
2026-10-01,Push,,Deadlift,,,,1,normal,100,kg,five,
2999-01-01,Push,,Deadlift,,,,1,normal,100,kg,5,
2026-10-01,Push,,Deadlift,,,,1,normal,100,kg,5,
''';
      final p = parseHistoryCsv(text);
      expect(p.problems, hasLength(5));
      expect(p.setCount, 1);
    });

    test('explains a missing header', () {
      final p = parseHistoryCsv('2026-10-01,Push,Deadlift,5');
      expect(p.workouts, isEmpty);
      expect(p.problems.single, contains('column'));
    });
  });

  group('HistoryImporter', () {
    late AppDatabase db;
    late HistoryImporter importer;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      importer = HistoryImporter(db);
    });
    tearDown(() => db.close());

    test('imports workouts, sets and new exercises', () async {
      final preview = await importer.preview(parseHistoryCsv(sample));
      expect(preview.canImport, isTrue);
      expect(preview.newExercises.map((e) => e.name), [
        'Landmine Press, single arm',
      ]);

      final result = await importer.run(preview);
      expect(result.workouts, 2);
      expect(result.sets, 7);
      expect(result.exercisesCreated, 1);

      final workouts = await db.select(db.workouts).get();
      expect(
        workouts.every((w) => w.status == WorkoutStatus.completed),
        isTrue,
      );
      final push = workouts.firstWhere((w) => w.name == 'Push Day');
      expect(push.startedAt, importStartTime(DateTime(2026, 10, 12)));
      expect(push.durationSeconds, 65 * 60);

      final custom = await (db.select(
        db.exercises,
      )..where((e) => e.name.equals('Landmine Press, single arm'))).getSingle();
      expect(custom.isCustom, isTrue);
    });

    test(
      'stores assistance as negative kg and timed sets without weight',
      () async {
        await importer.run(await importer.preview(parseHistoryCsv(sample)));
        final sets = await db.select(db.workoutSets).get();
        final snapshots = await db.select(db.workoutExercises).get();
        WorkoutSet setFor(String name) {
          final we = snapshots.firstWhere(
            (s) => s.exerciseNameSnapshot == name,
          );
          return sets.firstWhere((s) => s.workoutExerciseId == we.id);
        }

        expect(setFor('Assisted Pull-up').weightKg, -20);
        final plank = setFor('Plank');
        expect(plank.durationSeconds, 60);
        expect(plank.weightKg, isNull);
        expect(plank.reps, isNull);
        expect(sets.every((s) => s.isCompleted), isTrue);
      },
    );

    test('importing the same CSV twice adds nothing the second time', () async {
      await importer.run(await importer.preview(parseHistoryCsv(sample)));
      final again = await importer.preview(parseHistoryCsv(sample));
      expect(again.toImport, isEmpty);
      expect(again.alreadyImported, hasLength(2));
      expect(await db.select(db.workouts).get(), hasLength(2));
    });

    test('blocks unknown exercises that lack details', () async {
      const text = '$header\n2026-10-01,Legs,,Sissy Squat,,,,1,normal,,,12,\n';
      final preview = await importer.preview(parseHistoryCsv(text));
      expect(preview.unknownExercises, ['Sissy Squat']);
      expect(preview.canImport, isFalse);
      expect(() => importer.run(preview), throwsStateError);
    });

    test('imports band sets with their band level', () async {
      const text =
          '$header,band\n'
          '2026-10-03,Home,,Band Face Pull,,,,1,normal,,,15,,heavy\n';
      await importer.run(await importer.preview(parseHistoryCsv(text)));
      final set = await db.select(db.workoutSets).getSingle();
      expect(set.bandLevel, BandLevel.heavy);
      expect(set.reps, 15);
      expect(set.weightKg, isNull);
    });

    test('matches library names regardless of case', () async {
      const text =
          '$header\n2026-10-01,Legs,,back squat,,,,1,normal,100,kg,5,\n';
      final preview = await importer.preview(parseHistoryCsv(text));
      expect(preview.newExercises, isEmpty);
      await importer.run(preview);
      final we = await db.select(db.workoutExercises).getSingle();
      expect(we.exerciseNameSnapshot, 'Back Squat');
    });
  });
}
