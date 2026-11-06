import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'health_service.dart';
import 'health_service_stub.dart' as stub;

HealthService createPlatformHealthService() =>
    Platform.isAndroid ? _HealthConnect() : stub.createPlatformHealthService();

class _HealthConnect implements HealthService {
  final _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.STEPS, HealthDataType.WEIGHT];
  static const _access = [HealthDataAccess.READ, HealthDataAccess.READ_WRITE];

  Future<void> _ready() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthAvailability> availability() async {
    try {
      await _ready();
      return switch (await _health.getHealthConnectSdkStatus()) {
        HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthAvailability.needsUpdate,
        _ => HealthAvailability.unavailable,
      };
    } catch (_) {
      return HealthAvailability.unavailable;
    }
  }

  @override
  Future<bool> connect() async {
    await _ready();
    await _health.requestAuthorization(_types, permissions: _access);
    return isConnected();
  }

  Future<bool> _has(HealthDataType type, HealthDataAccess access) async {
    try {
      await _ready();
      final ok =
          await _health.hasPermissions([type], permissions: [access]) ?? false;
      debugPrint('LOCKIN_HEALTH has ${type.name} ${access.name}: $ok');
      return ok;
    } catch (e) {
      debugPrint('LOCKIN_HEALTH has ${type.name} ${access.name} failed: $e');
      return false;
    }
  }

  @override
  Future<bool> canReadSteps() =>
      _has(HealthDataType.STEPS, HealthDataAccess.READ);

  @override
  Future<bool> canReadWeight() =>
      _has(HealthDataType.WEIGHT, HealthDataAccess.READ);

  @override
  Future<bool> isConnected() async =>
      await canReadSteps() || await canReadWeight();

  @override
  Future<bool> canWriteWeight() =>
      _has(HealthDataType.WEIGHT, HealthDataAccess.READ_WRITE);

  @override
  Future<bool> hasFullHistory() async {
    try {
      await _ready();
      return await _health.isHealthDataHistoryAuthorized();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestFullHistory() async {
    await _ready();
    if (!await _health.isHealthDataHistoryAvailable()) return false;
    return _health.requestHealthDataHistoryAuthorization();
  }

  @override
  Future<void> install() async {
    await _ready();
    await _health.installHealthConnect();
  }

  @override
  Future<int?> steps(DateTime start, DateTime end) async {
    await _ready();
    return _health.getTotalStepsInInterval(start, end);
  }

  @override
  Future<List<HealthWeight>> weights(DateTime start, DateTime end) async {
    await _ready();
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WEIGHT],
      startTime: start,
      endTime: end,
    );
    return [
      for (final p in points)
        if (p.value is NumericHealthValue)
          (
            at: p.dateFrom,
            kg: (p.value as NumericHealthValue).numericValue.toDouble(),
            source: p.sourceName,
          ),
    ];
  }

  @override
  Future<bool> writeWeight(double kg, DateTime at) async {
    await _ready();
    return _health.writeHealthData(
      value: kg,
      type: HealthDataType.WEIGHT,
      startTime: at,
      endTime: at,
      recordingMethod: RecordingMethod.manual,
    );
  }
}
