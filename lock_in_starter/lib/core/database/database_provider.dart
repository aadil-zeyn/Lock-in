import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// The single database instance for the app.
/// Override in tests with `databaseProvider.overrideWithValue(...)`.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
