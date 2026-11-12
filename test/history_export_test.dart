import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/core/database/app_database.dart';
import 'package:lock_in/features/exercises/data/exercise_repository.dart';
import 'package:lock_in/features/history_import/data/history_csv.dart';
import 'package:lock_in/features/history_import/data/history_export.dart';
import 'package:lock_in/features/history_import/data/history_importer.dart';

const _logged =
    'date,workout,duration_min,exercise,primary_muscle,equipment,tracking,set,set_type,weight,unit,reps,seconds\n'
    '2026-10-12,Push Day,65,Barbell Bench Press,,,,1,warmup,40,kg,10,\n'
    '2026-10-12,Push Day,65,Barbell Bench Press,,,,2,normal,60,kg,8,\n'
    '2026-10-12,Push Day,65,Tricep Pushdown,,,,1,normal,25,kg,12,\n'
    '2026-10-14,Pull Day,,Assisted Pull-up,,,,1,normal,20,kg,8,\n';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('exports custom exercises and every ticked set', () async {
    await ExerciseRepository(db).create(
      const ExerciseDraft(
        name: 'Rope Hammer Curl',
        primaryMuscle: MuscleGroup.biceps,
        equipment: Equipment.cable,
        trackingType: TrackingType.weightReps,
        secondaryMuscles: {MuscleGroup.forearms},
        description: 'Thumbs up, elbows in',
      ),
    );
    final importer = HistoryImporter(db);
    await importer.run(await importer.preview(parseHistoryCsv(_logged)));

    final csv = await exportHistoryCsv(db);
    final lines = csv.trim().split('\n');
    expect(lines.first, exportCsvHeader);
    expect(
      lines[1],
      ',,,Rope Hammer Curl,biceps,cable,weightReps,,,,,,,,,,forearms,'
      '"Thumbs up, elbows in"',
    );
    expect(lines, hasLength(1 + 1 + 4));
    expect(
      lines,
      contains(
        startsWith(
          '2026-10-12,Push Day,65,Barbell Bench Press,chest,barbell,weightReps,1,warmup,40,kg,10,',
        ),
      ),
    );
    // Assisted weights are written unsigned; the importer signs them again.
    expect(
      lines.last,
      startsWith(
        '2026-10-14,Pull Day,,Assisted Pull-up,back,machine,assistedBodyweight,1,normal,20,kg,8,',
      ),
    );
  });

  test('round-trips into another database', () async {
    final importer = HistoryImporter(db);
    await importer.run(await importer.preview(parseHistoryCsv(_logged)));
    final csv = await exportHistoryCsv(db);

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final parsed = parseHistoryCsv(csv);
    expect(parsed.problems, isEmpty);
    final result = await HistoryImporter(other)
        .run(await HistoryImporter(other).preview(parsed));
    expect(result.workouts, 2);
    expect(result.sets, 4);
  });
}
