import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

typedef ExerciseFilter = ({String query, MuscleGroup? muscle});

/// Non-archived exercises matching a search query and optional muscle.
final exerciseListProvider = StreamProvider.autoDispose
    .family<List<Exercise>, ExerciseFilter>((ref, filter) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.exercises)..where((e) => e.archivedAt.isNull());

  final text = filter.query.trim();
  if (text.isNotEmpty) {
    query.where((e) => e.name.like('%$text%'));
  }
  if (filter.muscle != null) {
    query.where((e) => e.primaryMuscle.equalsValue(filter.muscle));
  }
  query.orderBy([(e) => OrderingTerm.asc(e.name)]);
  return query.watch();
});
