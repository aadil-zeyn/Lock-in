import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../data/workout_repository.dart';

/// Opens the workout in progress, or starts a new empty one.
Future<void> startOrResumeWorkout(BuildContext context, WidgetRef ref) async {
  await ref.read(workoutRepositoryProvider).start();
  if (context.mounted) await context.push(Routes.activeWorkout);
}

/// Live "12:34" / "1:02:03" for a running workout.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}
