import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rest timer state: when the rest ends, plus its full length for the
/// progress ring. Stored as an end timestamp (PRD v1.1 §3), so time keeps
/// counting correctly while the app is in the background.
class RestState {
  const RestState({required this.endsAt, required this.total});
  final DateTime endsAt;
  final Duration total;

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

class RestTimer extends Notifier<RestState?> {
  @override
  RestState? build() => null;

  void start(Duration length, {DateTime? now}) {
    if (length <= Duration.zero) return;
    state = RestState(
      endsAt: (now ?? DateTime.now()).add(length),
      total: length,
    );
  }

  /// Adds (or with a negative value removes) time from the running rest.
  void adjust(Duration delta, {DateTime? now}) {
    final s = state;
    if (s == null) return;
    final at = now ?? DateTime.now();
    final endsAt = s.endsAt.add(delta);
    if (!endsAt.isAfter(at)) {
      state = null;
      return;
    }
    final total = s.total + delta;
    state = RestState(
      endsAt: endsAt,
      total: total > Duration.zero ? total : endsAt.difference(at),
    );
  }

  void stop() => state = null;
}

final restTimerProvider = NotifierProvider<RestTimer, RestState?>(
  RestTimer.new,
);
