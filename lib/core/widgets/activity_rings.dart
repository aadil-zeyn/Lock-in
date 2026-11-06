import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One ring in [ActivityRings]. [progress] is 0..1+ (values above 1 wrap
/// around with a slightly brighter overlap, like fitness bands do).
class RingData {
  const RingData({required this.progress, required this.color});
  final double progress;
  final Color color;
}

/// Concentric progress rings, outermost first.
class ActivityRings extends StatelessWidget {
  const ActivityRings({
    super.key,
    required this.rings,
    this.size = 140,
    this.strokeWidth = 14,
    this.gap = 4,
    this.center,
    this.semanticsLabel,
  });

  final List<RingData> rings;
  final double size;
  final double strokeWidth;
  final double gap;
  final Widget? center;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => CustomPaint(
            painter: _RingsPainter(rings, strokeWidth, gap, t),
            child: child,
          ),
          child: center == null ? null : Center(child: center),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings, this.stroke, this.gap, this.t);

  final List<RingData> rings;
  final double stroke;
  final double gap;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    var radius = size.shortestSide / 2 - stroke / 2;

    for (final ring in rings) {
      final rect = Rect.fromCircle(center: c, radius: radius);
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = ring.color.withValues(alpha: 0.18);
      canvas.drawCircle(c, radius, track);

      final p = (ring.progress.clamp(0.0, 2.0)) * t;
      if (p > 0) {
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: 2 * math.pi,
            transform: const GradientRotation(-math.pi / 2),
            colors: [
              Color.lerp(ring.color, Colors.white, 0.0)!,
              Color.lerp(ring.color, Colors.white, 0.25)!,
            ],
          ).createShader(rect);
        // Tiny minimum so a started ring shows as a dot, not nothing.
        final sweep = math.max(p, 0.005) * 2 * math.pi;
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.min(sweep, 2 * math.pi),
          false,
          arc,
        );
        if (p > 1) {
          final overlap = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(ring.color, Colors.white, 0.3)!;
          canvas.drawArc(
            rect,
            -math.pi / 2,
            (p - 1) * 2 * math.pi,
            false,
            overlap,
          );
        }
      }
      radius -= stroke + gap;
      if (radius <= stroke / 2) break;
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.t != t || old.rings != rings || old.stroke != stroke;
}
