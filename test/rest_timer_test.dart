import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lock_in/features/workout/data/rest_timer.dart';
import 'package:lock_in/features/workout/presentation/workout_actions.dart';

void main() {
  final t0 = DateTime(2026, 11, 6, 18);

  test('counts down from the end timestamp, never below zero', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(restTimerProvider.notifier)
        .start(const Duration(seconds: 90), now: t0);
    final s = c.read(restTimerProvider)!;
    expect(
      s.remaining(t0.add(const Duration(seconds: 30))),
      const Duration(seconds: 60),
    );
    expect(s.remaining(t0.add(const Duration(minutes: 5))), Duration.zero);
  });

  test('+15s / −15s adjust; going past zero stops it', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final timer = c.read(restTimerProvider.notifier);
    timer.start(const Duration(seconds: 20), now: t0);
    timer.adjust(const Duration(seconds: 15), now: t0);
    expect(
      c.read(restTimerProvider)!.remaining(t0),
      const Duration(seconds: 35),
    );
    timer.adjust(const Duration(seconds: -60), now: t0);
    expect(c.read(restTimerProvider), isNull);
  });

  test('clock format', () {
    expect(formatClock(const Duration(seconds: 75)), '1:15');
    expect(
      formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
