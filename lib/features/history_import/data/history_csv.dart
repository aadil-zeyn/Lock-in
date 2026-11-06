import '../../../core/database/enums.dart';
import '../../../core/utils/units.dart';

/// Parses the CSV written by the Lock-in History Logger page.
///
/// Columns (header row required, any order, extra columns ignored):
///   date, workout, duration_min, exercise, primary_muscle, equipment,
///   tracking, set, set_type, weight, unit, reps, seconds, band
/// `band` is a BandLevel name (extraLight … extraHeavy) for band exercises.
/// One row per set. `primary_muscle` / `equipment` / `tracking` are only
/// needed for exercises that aren't in the library yet.
///
/// Weights are converted to kg here. For assisted exercises the weight is
/// the assistance and is stored as a negative number, matching
/// `effectiveBodyweightLoad` in `core/utils/strength.dart`.

class ImportSet {
  const ImportSet({
    required this.type,
    this.weightKg,
    this.reps,
    this.seconds,
    this.band,
  });
  final SetType type;
  final double? weightKg;
  final int? reps;
  final int? seconds;
  final BandLevel? band;
}

/// How to create an exercise that isn't in the library.
class NewExerciseSpec {
  const NewExerciseSpec({
    required this.muscle,
    required this.equipment,
    required this.tracking,
  });
  final MuscleGroup muscle;
  final Equipment equipment;
  final TrackingType tracking;
}

class ImportExercise {
  ImportExercise(this.name);
  final String name;
  NewExerciseSpec? spec;

  /// Sets as written in the CSV (weights in kg, unsigned). Assisted
  /// weights are signed at import, once the tracking type is known — it
  /// may come from the library rather than the CSV.
  final List<ImportSet> rawSets = [];
}

class ImportWorkout {
  ImportWorkout({required this.date, required this.name, this.durationMin});
  final DateTime date;
  final String name;
  int? durationMin;
  final List<ImportExercise> exercises = [];

  int get setCount => exercises.fold(0, (n, e) => n + e.rawSets.length);
}

class ParsedHistory {
  ParsedHistory(this.workouts, this.problems);
  final List<ImportWorkout> workouts;

  /// Human-readable issues, e.g. "Line 7: reps must be a whole number".
  final List<String> problems;

  int get setCount => workouts.fold(0, (n, w) => n + w.setCount);
}

const _required = ['date', 'exercise'];

ParsedHistory parseHistoryCsv(String text) {
  final rows = _splitCsv(text);
  final problems = <String>[];
  if (rows.isEmpty) return ParsedHistory([], ['The text is empty.']);

  final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
  for (final col in _required) {
    if (!header.contains(col)) {
      return ParsedHistory([], [
        'Missing the "$col" column. Copy the CSV from the History Logger, '
            'including its first line.',
      ]);
    }
  }
  if (!header.contains('reps') && !header.contains('seconds')) {
    return ParsedHistory([], ['Missing a "reps" or "seconds" column.']);
  }
  String col(List<String> r, String name) {
    final i = header.indexOf(name);
    return i < 0 || i >= r.length ? '' : r[i].trim();
  }

  final workouts = <String, ImportWorkout>{};
  final today = DateTime.now();

  for (var i = 1; i < rows.length; i++) {
    final r = rows[i];
    final line = i + 1;
    if (r.every((c) => c.trim().isEmpty)) continue;

    final date = DateTime.tryParse(col(r, 'date'));
    if (date == null || col(r, 'date').length != 10) {
      problems.add('Line $line: date must look like 2026-10-14.');
      continue;
    }
    if (date.isAfter(DateTime(today.year, today.month, today.day))) {
      problems.add('Line $line: ${col(r, 'date')} is in the future.');
      continue;
    }
    final exerciseName = col(r, 'exercise').replaceAll(RegExp(r'\s+'), ' ');
    if (exerciseName.isEmpty || exerciseName.length > 80) {
      problems.add('Line $line: exercise name is missing or too long.');
      continue;
    }

    var badNumber = false;
    int? whole(String name) {
      final v = col(r, name);
      if (v.isEmpty) return null;
      final n = int.tryParse(v);
      if (n == null || n < 0) {
        problems.add('Line $line: $name must be a whole number.');
        badNumber = true;
      }
      return n;
    }

    final reps = whole('reps');
    final seconds = whole('seconds');
    if (badNumber) continue;
    final weightText = col(r, 'weight').replaceAll(',', '.');
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);
    if (weightText.isNotEmpty && (weight == null || weight < 0)) {
      problems.add('Line $line: weight must be a number.');
      continue;
    }
    if ((reps ?? 0) <= 0 && (seconds ?? 0) <= 0) {
      problems.add('Line $line: needs reps or seconds.');
      continue;
    }
    final unit = col(r, 'unit').toLowerCase() == 'lb'
        ? WeightUnit.lb
        : WeightUnit.kg;
    final setType = SetType.values.firstWhere(
      (t) => t.name == col(r, 'set_type').toLowerCase(),
      orElse: () => SetType.normal,
    );

    final workoutName = col(r, 'workout').isEmpty
        ? 'Workout'
        : col(r, 'workout');
    final key = '${col(r, 'date')}|${workoutName.toLowerCase()}';
    final workout = workouts.putIfAbsent(
      key,
      () => ImportWorkout(
        date: DateTime(date.year, date.month, date.day),
        name: workoutName.length > 60
            ? workoutName.substring(0, 60)
            : workoutName,
      ),
    );
    final dur = int.tryParse(col(r, 'duration_min'));
    if (dur != null && dur > 0) workout.durationMin ??= dur;

    var exercise = workout.exercises
        .where((e) => e.name.toLowerCase() == exerciseName.toLowerCase())
        .firstOrNull;
    if (exercise == null) {
      exercise = ImportExercise(exerciseName);
      workout.exercises.add(exercise);
    }
    exercise.spec ??= _specFrom(
      col(r, 'primary_muscle'),
      col(r, 'equipment'),
      col(r, 'tracking'),
    );
    exercise.rawSets.add(
      ImportSet(
        type: setType,
        weightKg: weight == null ? null : displayToKg(weight, unit),
        reps: (reps ?? 0) > 0 ? reps : null,
        seconds: (seconds ?? 0) > 0 ? seconds : null,
        band: BandLevel.values
            .where((b) => b.name == col(r, 'band'))
            .firstOrNull,
      ),
    );
  }

  final list = workouts.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return ParsedHistory(list, problems);
}

NewExerciseSpec? _specFrom(String muscle, String equipment, String tracking) {
  final m = MuscleGroup.values.where((v) => v.name == muscle).firstOrNull;
  final e = Equipment.values.where((v) => v.name == equipment).firstOrNull;
  if (m == null || e == null) return null;
  final t =
      TrackingType.values.where((v) => v.name == tracking).firstOrNull ??
      TrackingType.weightReps;
  return NewExerciseSpec(muscle: m, equipment: e, tracking: t);
}

/// RFC 4180-style splitter: quoted fields, doubled quotes, CRLF or LF.
List<List<String>> _splitCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
