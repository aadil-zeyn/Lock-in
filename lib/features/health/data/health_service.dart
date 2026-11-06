import 'health_service_stub.dart'
    if (dart.library.io) 'health_service_android.dart'
    as impl;

/// Whether Health Connect can be used on this device.
enum HealthAvailability {
  /// Ready to connect.
  available,

  /// Installed but needs an update from the Play Store.
  needsUpdate,

  /// Not on this device (web, old Android, or not installed).
  unavailable,
}

/// One body-weight reading from Health Connect.
typedef HealthWeight = ({DateTime at, double kg, String source});

/// The app's view of Health Connect. Opt-in: nothing is read or written
/// until the user connects from Profile → Health Connect.
abstract class HealthService {
  Future<HealthAvailability> availability();

  /// Asks the user for steps (read) and weight (read + write).
  Future<bool> connect();

  /// True when steps and weight access are both granted.
  Future<bool> isConnected();

  /// Separate Android permission for data older than 30 days.
  Future<bool> hasFullHistory();
  Future<bool> requestFullHistory();

  /// Opens the Play Store page for Health Connect.
  Future<void> install();

  /// Total steps from [start] to [end] (deduplicated across sources).
  Future<int?> steps(DateTime start, DateTime end);

  Future<List<HealthWeight>> weights(DateTime start, DateTime end);

  Future<bool> writeWeight(double kg, DateTime at);
}

HealthService createHealthService() => impl.createPlatformHealthService();
