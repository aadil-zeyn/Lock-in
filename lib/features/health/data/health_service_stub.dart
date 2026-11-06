import 'health_service.dart';

/// Web and other platforms: Health Connect is Android-only.
HealthService createPlatformHealthService() => _Unavailable();

class _Unavailable implements HealthService {
  @override
  Future<HealthAvailability> availability() async =>
      HealthAvailability.unavailable;
  @override
  Future<bool> connect() async => false;
  @override
  Future<bool> isConnected() async => false;
  @override
  Future<bool> canWriteWeight() async => false;
  @override
  Future<bool> canReadSteps() async => false;
  @override
  Future<bool> canReadWeight() async => false;
  @override
  Future<bool> hasFullHistory() async => false;
  @override
  Future<bool> requestFullHistory() async => false;
  @override
  Future<void> install() async {}
  @override
  Future<int?> steps(DateTime start, DateTime end) async => null;
  @override
  Future<List<({DateTime day, int steps})>> dailySteps(
    DateTime firstDay,
  ) async => const [];
  @override
  Future<List<HealthWeight>> weights(DateTime start, DateTime end) async =>
      const [];
  @override
  Future<bool> writeWeight(double kg, DateTime at) async => false;
}
