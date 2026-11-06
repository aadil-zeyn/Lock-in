import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const exerciseNameMaxLength = 80;

/// Thrown when a name clashes (case-insensitively) with another exercise
/// that is visible in the library.
class DuplicateExerciseNameException implements Exception {
  const DuplicateExerciseNameException(this.name);
  final String name;
  @override
  String toString() => 'An exercise called "$name" already exists';
}

/// Thrown when trying to edit a built-in exercise.
class BuiltInExerciseException implements Exception {
  const BuiltInExerciseException();
  @override
  String toString() => 'Built-in exercises can\'t be edited';
}

/// Trims and collapses internal whitespace: "  Cable   Fly " → "Cable Fly".
String normalizeExerciseName(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Null when valid, otherwise a message for the form field.
String? validateExerciseName(String raw) {
  final name = normalizeExerciseName(raw);
  if (name.isEmpty) return 'Give the exercise a name';
  if (name.length > exerciseNameMaxLength) {
    return 'Keep it under $exerciseNameMaxLength characters';
  }
  return null;
}

List<MuscleGroup> decodeMuscles(String csv) => [
  for (final part in csv.split(','))
    if (part.isNotEmpty) ...MuscleGroup.values.where((m) => m.name == part),
];

/// Encodes in enum order so equal sets always produce the same string.
String encodeMuscles(Iterable<MuscleGroup> muscles) {
  final set = muscles.toSet();
  return MuscleGroup.values.where(set.contains).map((m) => m.name).join(',');
}

extension ExerciseX on Exercise {
  List<MuscleGroup> get secondaryMuscleList => decodeMuscles(secondaryMuscles);
  bool get isArchived => archivedAt != null;
}

/// Everything the create/edit form collects.
class ExerciseDraft {
  const ExerciseDraft({
    required this.name,
    required this.primaryMuscle,
    required this.equipment,
    required this.trackingType,
    this.secondaryMuscles = const {},
    this.description,
  });

  factory ExerciseDraft.fromExercise(Exercise e) => ExerciseDraft(
    name: e.name,
    primaryMuscle: e.primaryMuscle,
    equipment: e.equipment,
    trackingType: e.trackingType,
    secondaryMuscles: e.secondaryMuscleList.toSet(),
    description: e.description,
  );

  final String name;
  final MuscleGroup primaryMuscle;
  final Set<MuscleGroup> secondaryMuscles;
  final Equipment equipment;
  final TrackingType trackingType;
  final String? description;

  String get cleanName => normalizeExerciseName(name);

  /// Secondary muscles never include the primary one.
  String get encodedSecondary =>
      encodeMuscles(secondaryMuscles.where((m) => m != primaryMuscle));

  String? get cleanDescription {
    final d = description?.trim();
    return (d == null || d.isEmpty) ? null : d;
  }
}

class ExerciseRepository {
  ExerciseRepository(this._db);
  final AppDatabase _db;

  /// True if a non-archived exercise (other than [exceptId]) has this name,
  /// ignoring case and extra spaces.
  Future<bool> isNameTaken(String name, {int? exceptId}) async {
    final clean = normalizeExerciseName(name).toLowerCase();
    final query = _db.select(_db.exercises)
      ..where((e) => e.archivedAt.isNull() & e.name.lower().equals(clean));
    if (exceptId != null) query.where((e) => e.id.equals(exceptId).not());
    return (await query.get()).isNotEmpty;
  }

  Future<int> create(ExerciseDraft draft) {
    _checkValid(draft);
    return _db.transaction(() async {
      if (await isNameTaken(draft.cleanName)) {
        throw DuplicateExerciseNameException(draft.cleanName);
      }
      return _db
          .into(_db.exercises)
          .insert(
            ExercisesCompanion.insert(
              name: draft.cleanName,
              primaryMuscle: draft.primaryMuscle,
              secondaryMuscles: Value(draft.encodedSecondary),
              equipment: draft.equipment,
              trackingType: draft.trackingType,
              description: Value(draft.cleanDescription),
              isCustom: const Value(true),
            ),
          );
    });
  }

  /// Only custom exercises can be edited. Past workouts keep the name they
  /// were logged with (`exerciseNameSnapshot`).
  Future<void> update(int id, ExerciseDraft draft) {
    _checkValid(draft);
    return _db.transaction(() async {
      final existing = await _get(id);
      if (!existing.isCustom) throw const BuiltInExerciseException();
      if (await isNameTaken(draft.cleanName, exceptId: id)) {
        throw DuplicateExerciseNameException(draft.cleanName);
      }
      await (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
        ExercisesCompanion(
          name: Value(draft.cleanName),
          primaryMuscle: Value(draft.primaryMuscle),
          secondaryMuscles: Value(draft.encodedSecondary),
          equipment: Value(draft.equipment),
          trackingType: Value(draft.trackingType),
          description: Value(draft.cleanDescription),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Hides an exercise from the library. History and stats keep it.
  Future<void> archive(int id) => _setArchived(id, DateTime.now());

  /// Brings an archived exercise back. Fails if its name is now taken.
  Future<void> restore(int id) {
    return _db.transaction(() async {
      final existing = await _get(id);
      if (await isNameTaken(existing.name, exceptId: id)) {
        throw DuplicateExerciseNameException(existing.name);
      }
      await _setArchived(id, null);
    });
  }

  Future<void> _setArchived(int id, DateTime? at) async {
    await (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        archivedAt: Value(at),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Exercise> _get(int id) =>
      (_db.select(_db.exercises)..where((e) => e.id.equals(id))).getSingle();

  void _checkValid(ExerciseDraft draft) {
    final error = validateExerciseName(draft.name);
    if (error != null) throw ArgumentError(error);
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);
