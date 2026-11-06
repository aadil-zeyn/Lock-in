import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../body/data/body_repository.dart';
import 'health_service.dart';

final healthServiceProvider = Provider<HealthService>(
  (ref) => createHealthService(),
);

class HealthStatus {
  const HealthStatus({
    required this.availability,
    required this.connected,
    required this.fullHistory,
  });
  final HealthAvailability availability;
  final bool connected;
  final bool fullHistory;
}

/// Re-read with `ref.invalidate(healthStatusProvider)` after connecting.
final healthStatusProvider = FutureProvider<HealthStatus>((ref) async {
  final h = ref.watch(healthServiceProvider);
  final availability = await h.availability();
  if (availability != HealthAvailability.available) {
    return HealthStatus(
      availability: availability,
      connected: false,
      fullHistory: false,
    );
  }
  final connected = await h.isConnected();
  return HealthStatus(
    availability: availability,
    connected: connected,
    fullHistory: connected && await h.hasFullHistory(),
  );
});

/// Steps per day for the last 7 days, oldest first; today is last.
/// Null when Health Connect isn't connected.
final weekStepsProvider = FutureProvider<List<int>?>((ref) async {
  final status = await ref.watch(healthStatusProvider.future);
  if (!status.connected) return null;
  final h = ref.watch(healthServiceProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = <int>[];
  for (var i = 6; i >= 0; i--) {
    final start = today.subtract(Duration(days: i));
    final end = i == 0 ? now : start.add(const Duration(days: 1));
    days.add(await h.steps(start, end) ?? 0);
  }
  return days;
});

/// Pulls body weight from Health Connect into Lock-in. Reads everything
/// when full-history access is granted, otherwise the last 30 days.
Future<int> syncWeightsFromHealth({
  required HealthStatus status,
  required HealthService health,
  required BodyRepository body,
}) async {
  if (!status.connected) return 0;
  final now = DateTime.now();
  final since = status.fullHistory
      ? DateTime(now.year - 20)
      : now.subtract(const Duration(days: 30));
  final readings = await health.weights(since, now);
  return body.importWeights(readings.map((r) => (at: r.at, kg: r.kg)));
}

/// Runs the weight sync once per app launch, when connected.
final healthAutoSyncProvider = FutureProvider<int>((ref) async {
  try {
    return await syncWeightsFromHealth(
      status: await ref.watch(healthStatusProvider.future),
      health: ref.read(healthServiceProvider),
      body: ref.read(bodyRepositoryProvider),
    );
  } catch (_) {
    return 0; // a failed background sync never blocks the app
  }
});
