import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// A plotted point (x = time).
typedef PlotPoint = ({DateTime x, double y});

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "Nice" axis ticks covering [lo, hi]: steps of 1, 2, 2.5 or 5 × 10^n.
List<double> niceTicks(double lo, double hi, {int target = 4}) {
  if (hi <= lo) {
    final pad = lo.abs() * 0.02 + 1;
    lo -= pad;
    hi += pad;
  }
  final raw = (hi - lo) / target;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [
    1.0,
    2.0,
    2.5,
    5.0,
    10.0,
  ].map((m) => m * mag).firstWhere((s) => s >= raw, orElse: () => 10 * mag);
  final start = (lo / step).floor() * step;
  final ticks = <double>[];
  for (var v = start; v <= hi + step * 0.999; v += step) {
    ticks.add(double.parse(v.toStringAsFixed(6)));
  }
  return ticks;
}

/// Line chart over time: optional dots for raw values, an optional trend
/// line, hairline grid, drag-to-inspect crosshair. Text uses text colours;
/// only marks carry [color].
class TimeLineChart extends StatefulWidget {
  const TimeLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.formatValue,
    this.trend,
    this.formatAxis,
    this.height = 200,
    this.pointsLabel = 'Value',
    this.trendLabel = 'Trend',
    this.semanticsLabel,
  });

  /// Raw values, oldest first. Drawn as dots (or a faint line when dense).
  final List<PlotPoint> points;

  /// Smoothed line drawn on top, e.g. a 7-day average. When null the raw
  /// values are joined by the main line instead.
  final List<PlotPoint>? trend;
  final Color color;
  final String Function(double) formatValue;

  /// Short y-axis labels (no unit). Defaults to the plain number.
  final String Function(double)? formatAxis;
  final double height;
  final String pointsLabel;
  final String trendLabel;
  final String? semanticsLabel;

  @override
  State<TimeLineChart> createState() => _TimeLineChartState();
}

class _TimeLineChartState extends State<TimeLineChart> {
  int? _selected;

  void _select(Offset local, double width) {
    final pts = widget.points;
    if (pts.isEmpty) return;
    final layout = _ChartLayout(widget, Size(width, widget.height));
    var best = 0;
    var bestDx = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final dx = (layout.xOf(pts[i].x) - local.dx).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = i;
      }
    }
    if (best != _selected) setState(() => _selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final hasTrend = widget.trend != null;
    final sel = _selected != null && _selected! < widget.points.length
        ? widget.points[_selected!]
        : null;
    final trendAtSel = sel == null || !hasTrend
        ? null
        : widget.trend!
              .lastWhere(
                (t) => !t.x.isAfter(sel.x),
                orElse: () => widget.trend!.first,
              )
              .y;

    return Semantics(
      label: widget.semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 38,
            child: sel == null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Drag across the chart to see each entry',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  )
                : Row(
                    children: [
                      Text(
                        widget.formatValue(sel.y),
                        style: AppText.metricM.copyWith(fontSize: 20),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Date and trend shrink before the value does.
                      Expanded(
                        child: Text(
                          _shortDate(sel.x) +
                              (sel.x.year != DateTime.now().year
                                  ? ' ${sel.x.year}'
                                  : '') +
                              (trendAtSel == null
                                  ? ''
                                  : '  ·  avg ${widget.formatValue(trendAtSel)}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.unit,
                        ),
                      ),
                    ],
                  ),
          ),
          LayoutBuilder(
            builder: (context, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _select(d.localPosition, c.maxWidth),
              onHorizontalDragStart: (d) =>
                  _select(d.localPosition, c.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _select(d.localPosition, c.maxWidth),
              child: CustomPaint(
                size: Size(c.maxWidth, widget.height),
                painter: _LinePainter(widget, _selected),
              ),
            ),
          ),
          if (hasTrend) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _Key(dot: true, color: widget.color, label: widget.pointsLabel),
                const SizedBox(width: AppSpacing.lg),
                _Key(dot: false, color: widget.color, label: widget.trendLabel),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.dot, required this.color, required this.label});
  final bool dot;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot ? 8 : 16,
          height: dot ? 8 : 2,
          decoration: BoxDecoration(
            color: dot ? color.withValues(alpha: 0.55) : color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Shared geometry so painting and hit-testing agree.
class _ChartLayout {
  _ChartLayout(TimeLineChart w, Size size) {
    final all = [...w.points, ...?w.trend];
    var lo = all.map((p) => p.y).reduce(math.min);
    var hi = all.map((p) => p.y).reduce(math.max);
    final pad = (hi - lo) * 0.12;
    ticks = niceTicks(lo - pad, hi + pad);
    yMin = ticks.first;
    yMax = ticks.last;
    t0 = all.map((p) => p.x).reduce((a, b) => a.isBefore(b) ? a : b);
    t1 = all.map((p) => p.x).reduce((a, b) => a.isAfter(b) ? a : b);
    plot = Rect.fromLTRB(44, 8, size.width - 12, size.height - 24);
  }

  late final List<double> ticks;
  late final double yMin, yMax;
  late final DateTime t0, t1;
  late final Rect plot;

  double xOf(DateTime t) {
    final span = t1.difference(t0).inMinutes;
    if (span == 0) return plot.center.dx;
    return plot.left + plot.width * t.difference(t0).inMinutes / span;
  }

  double yOf(double v) =>
      plot.bottom -
      plot.height * (v - yMin) / (yMax - yMin == 0 ? 1 : yMax - yMin);
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.w, this.selected);
  final TimeLineChart w;
  final int? selected;

  /// Canvas width, so labels at the edges are kept inside it.
  double _maxX = double.infinity;

  @override
  void paint(Canvas canvas, Size size) {
    if (w.points.isEmpty) return;
    _maxX = size.width;
    final l = _ChartLayout(w, size);
    final grid = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;

    // Grid + y labels.
    for (final t in l.ticks) {
      final y = l.yOf(t);
      canvas.drawLine(Offset(l.plot.left, y), Offset(l.plot.right, y), grid);
      final axis =
          w.formatAxis?.call(t) ??
          (t == t.roundToDouble()
              ? t.toStringAsFixed(0)
              : t.toStringAsFixed(1));
      _text(canvas, axis, Offset(l.plot.left - 8, y), alignRight: true);
    }
    // X labels: first and last date (plus middle when wide).
    final xs = <DateTime>[l.t0, if (size.width > 320) _mid(l.t0, l.t1), l.t1];
    for (var i = 0; i < xs.length; i++) {
      if (i > 0 && xs[i] == xs[i - 1]) continue;
      _text(
        canvas,
        _shortDate(xs[i]),
        Offset(l.xOf(xs[i]), size.height - 8),
        center: true,
      );
    }

    final line = w.trend ?? w.points;
    final dense = w.points.length > 45;

    // Area wash under the main line (~10%).
    if (line.length > 1) {
      final area = Path()..moveTo(l.xOf(line.first.x), l.plot.bottom);
      for (final p in line) {
        area.lineTo(l.xOf(p.x), l.yOf(p.y));
      }
      area
        ..lineTo(l.xOf(line.last.x), l.plot.bottom)
        ..close();
      canvas.drawPath(area, Paint()..color = w.color.withValues(alpha: 0.10));
    }

    // Raw values under a trend: dots, or a faint line when dense.
    if (w.trend != null) {
      if (dense) {
        _polyline(canvas, l, w.points, w.color.withValues(alpha: 0.35), 1.5);
      } else {
        for (final p in w.points) {
          _dot(
            canvas,
            Offset(l.xOf(p.x), l.yOf(p.y)),
            w.color.withValues(alpha: 0.55),
            3.5,
          );
        }
      }
    }

    // Main line (2px, round joins).
    if (line.length > 1) _polyline(canvas, l, line, w.color, 2);
    if (w.trend == null && !dense) {
      for (final p in w.points) {
        _dot(canvas, Offset(l.xOf(p.x), l.yOf(p.y)), w.color, 4);
      }
    }
    // End dot on the latest value.
    final last = line.last;
    _dot(canvas, Offset(l.xOf(last.x), l.yOf(last.y)), w.color, 5);

    // Crosshair.
    final s = selected;
    if (s != null && s < w.points.length) {
      final p = w.points[s];
      final x = l.xOf(p.x);
      canvas.drawLine(
        Offset(x, l.plot.top),
        Offset(x, l.plot.bottom),
        Paint()
          ..color = AppColors.textTertiary
          ..strokeWidth = 1,
      );
      _dot(canvas, Offset(x, l.yOf(p.y)), w.color, 6);
    }
  }

  DateTime _mid(DateTime a, DateTime b) =>
      a.add(Duration(minutes: b.difference(a).inMinutes ~/ 2));

  void _polyline(
    Canvas c,
    _ChartLayout l,
    List<PlotPoint> pts,
    Color color,
    double width,
  ) {
    final path = Path()..moveTo(l.xOf(pts.first.x), l.yOf(pts.first.y));
    for (final p in pts.skip(1)) {
      path.lineTo(l.xOf(p.x), l.yOf(p.y));
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  /// Filled dot with a 2px ring in the card colour so it reads over lines.
  void _dot(Canvas c, Offset at, Color color, double r) {
    c.drawCircle(at, r + 2, Paint()..color = AppColors.surface);
    c.drawCircle(at, r, Paint()..color = color);
  }

  void _text(
    Canvas c,
    String s,
    Offset at, {
    bool alignRight = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textTertiary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? at.dx - tp.width
        : center
        ? at.dx - tp.width / 2
        : at.dx;
    final maxDx = (_maxX - tp.width).clamp(0.0, double.infinity);
    tp.paint(c, Offset(dx.clamp(0.0, maxDx), at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.w.points != w.points ||
      old.w.trend != w.trend ||
      old.selected != selected ||
      old.w.color != w.color;
}

/// Columns for a short series (e.g. workouts per week). The latest column
/// is full colour, earlier ones are de-emphasised; values sit on the caps.
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    this.height = 140,
    this.semanticsLabel,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(1, math.max);
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (values[i] > 0)
                      Text(
                        '${values[i]}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 22,
                      height: values[i] == 0
                          ? 3
                          : (height - 44) * values[i] / maxV,
                      decoration: BoxDecoration(
                        color: values[i] == 0
                            ? AppColors.outline
                            : (i == values.length - 1
                                  ? color
                                  : color.withValues(alpha: 0.5)),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: i == values.length - 1
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        fontWeight: i == values.length - 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
