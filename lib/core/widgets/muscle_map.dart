import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/muscle_style.dart';
import '../database/enums.dart';

enum BodyView { front, back }

/// One shape on the body diagram, in a 100 × 220 design space.
/// [muscle] null = a muscle that isn't tracked (neck, adductors, shins,
/// knees); it's always drawn neutral.
class BodyPart {
  const BodyPart(this.path, {this.muscle});
  final Path path;
  final MuscleGroup? muscle;
}

const _designSize = Size(100, 220);

/// The figure is drawn as its left half (x ≤ 50) and mirrored across the
/// centre line. Path data uses absolute SVG commands M, L, C and Z only.
const _silhouette =
    'M50 21 L44.8 21 C45 25 44.2 28 41.6 29.8 C37.4 31.6 31 31 26.5 33 '
    'C21.5 35 19.8 40 20 46 C18.6 54 17.8 62 17.6 70 C16.8 78 15 88 14 97.5 '
    'C12 100.5 10 105 10.4 110.5 C10.8 115 13 117.5 15.2 116.5 '
    'C17 114 16.8 109 18 104.5 C18.6 102 19.2 101 19.6 99 C21 90 23.8 82 25.4 74 '
    'C27 66 28.4 58 29.4 51.5 C31 60 33.6 72 34.2 82 C34.4 88 32 94 31.8 100 '
    'C30.8 115 31.8 132 35 148 C35 152 34.6 156 35 160 C33.4 172 35.4 186 37.8 196 '
    'C36 201.5 36.6 207.5 41 208.8 C44 209.6 47 208.8 47.4 205.8 '
    'C47 200 46.6 196 46.8 192 C48.4 180 49.2 166 48 156 '
    'C49 140 49.2 122 49.4 110 L50 108.5 Z';
const _head =
    'M50 1.5 C55.5 1.5 58.5 6 58.5 12 C58.5 18.5 55 23.5 50 23.5 '
    'C45 23.5 41.5 18.5 41.5 12 C41.5 6 44.5 1.5 50 1.5 Z';

// Later shapes overlap earlier ones; the gap stroke makes the seams.
const _front = <(MuscleGroup?, String)>[
  (
    null,
    'M46.4 24.2 C46.4 26.4 47.4 28.8 49.4 31.2 L49.4 33 C46.8 30.4 45.4 27.6 45.2 24.6 Z',
  ),
  (
    MuscleGroup.back,
    'M44.6 24.4 C44 28.2 40.6 30.6 33.4 32.6 C38.6 33.6 44 33.2 47.6 31.6 C46 29.6 45 27.2 44.6 24.4 Z',
  ),
  (
    MuscleGroup.core,
    'M30.8 51.4 C33.6 56.6 37.6 59.2 42 59 L42.2 87 C41 92 38 95 33 97.6 C34 91 34.6 85 34 79 C33.2 69 32.4 59 30.8 51.4 Z',
  ),
  (
    MuscleGroup.shoulders,
    'M34 33.4 C28 31.8 21.2 35 20.4 44.5 C20.2 49 21.2 52.4 22.6 55 C24.4 49.6 27.6 45 31.4 42 C33 39 34.2 36 34 33.4 Z',
  ),
  (
    MuscleGroup.chest,
    'M49.4 34.2 L49.4 53.6 C43.4 56.4 35.2 55 30.6 47.6 C31.6 42.4 33 38.4 34.4 35 C39.4 33.4 45 33.4 49.4 34.2 Z',
  ),
  (
    MuscleGroup.triceps,
    'M21.6 47.8 C19.6 53 18.6 60 18.4 67 C18.8 69.4 19.8 70.6 20.8 70.8 C20.2 63 20.8 55 22.6 50.8 Z',
  ),
  (
    MuscleGroup.biceps,
    'M29 50.2 C24.6 52.4 21.4 58 20.8 65.4 C21 69.2 23.2 71.4 25.6 70.6 C27.6 64.4 28.9 57.4 29 50.2 Z',
  ),
  (
    MuscleGroup.forearms,
    'M25.4 72.6 C23.4 73 21.8 73 20.6 72.6 C19.6 80 18.2 89 17.2 98.4 L19.4 99 C21 90 23.8 81 25.4 74 Z',
  ),
  (
    MuscleGroup.forearms,
    'M20.6 72.6 C19.6 80 18.2 89 17.2 98.4 L14.8 97.6 C15.8 88 17 78 18.4 71.8 C19 72.2 19.8 72.4 20.6 72.6 Z',
  ),
  (
    MuscleGroup.abs,
    'M49.4 55.4 L49.4 63.6 L43.2 63.8 C42.8 61 42.8 58.4 43.2 56.6 C45.4 55.4 47.4 55.2 49.4 55.4 Z',
  ),
  (
    MuscleGroup.abs,
    'M49.4 65 L49.4 73.4 L43 73.6 C42.6 70.8 42.6 67.8 43 65.2 Z',
  ),
  (
    MuscleGroup.abs,
    'M49.4 74.8 L49.4 83.4 L43.2 83.8 C42.8 80.8 42.8 77.8 43 75 Z',
  ),
  (
    MuscleGroup.abs,
    'M49.4 84.8 L49.4 101.4 C46.8 99.4 44.8 95.4 43.6 90.4 L43.2 85.2 Z',
  ),
  (
    MuscleGroup.quadriceps,
    'M32.4 99.6 C31.2 115 32 132 35 147.4 C38 149.6 42.4 149.4 45.2 148.6 C47.6 148 48.6 146 48.8 142 C48.8 132 48 120 46 108.4 C42.6 103 38 100 32.4 99.6 Z',
  ),
  (
    MuscleGroup.quadriceps,
    'M36 101.8 C39.8 109 41.4 124 41 139.4 C41.2 143.6 42.6 145.8 44.2 145.2 C45.4 138 45.4 122 43.6 111 C41.8 105.4 39.4 102.6 36 101.8 Z',
  ),
  (
    MuscleGroup.quadriceps,
    'M48.6 128 C45.6 132 43.8 138 44 143.6 C44.6 147 47 148.4 48.6 146.4 C49 140 49 134 48.6 128 Z',
  ),
  (
    null,
    'M45 103.6 C47 107.6 48.6 110.4 49.4 111 L49 128 C47.8 124.4 46.6 122.2 45.8 122 C45.8 115.6 45.6 109 45 103.6 Z',
  ),
  (
    null,
    'M36.6 149.6 C35.6 152.4 36 155.6 37.6 157.4 C40.4 158.6 43.8 158.4 46.2 156.8 C47.6 154 47.4 151.2 46 149.6 C43 150.8 39.6 150.8 36.6 149.6 Z',
  ),
  (
    MuscleGroup.calves,
    'M35.2 160.6 C33.8 170 35 182 37.4 192 C37 182 36.8 170 37.4 161 Z',
  ),
  (
    null,
    'M37.8 158.6 C36.8 170 37.6 182 39.8 193 C41.8 186 43 174 42.6 161 C41 158.8 39.2 158.2 37.8 158.6 Z',
  ),
  (
    MuscleGroup.calves,
    'M47.8 157.6 C49.2 166 49 177 47.4 187 C44.8 182 43.6 172 44.4 161 C45.4 158.8 46.6 157.8 47.8 157.6 Z',
  ),
];

const _back = <(MuscleGroup?, String)>[
  (
    MuscleGroup.back,
    'M30.6 46 C34 49 38.6 51.4 43.6 51 C45.4 56.4 47.4 62 48.4 67.6 C45.6 76 41.6 83 36.6 87.6 C35.6 76 33.8 60 30.6 46 Z',
  ),
  (
    MuscleGroup.back,
    'M39 39.6 C35 40.2 32 42.6 31 46.8 C33.8 50.8 38.4 52.2 43 50.6 C42.4 46 41.2 42.4 39 39.6 Z',
  ),
  (
    MuscleGroup.back,
    'M50 21.6 L50 60 C47.6 55.4 44.6 50.6 41 44.6 C38 40 34.4 36.4 30.4 33.6 C36.2 32 41.2 30 44 27.2 C45.2 25.6 45.2 23.6 45.2 21.6 Z',
  ),
  (
    MuscleGroup.back,
    'M49.4 60 L49.4 97 C46.6 97 43.8 96 41.6 94.4 C42.4 84 44.8 71 49.4 60 Z',
  ),
  (
    MuscleGroup.core,
    'M34.6 86 C37.8 84.4 40.2 83 42 82.4 C41.4 86.8 41 90.6 41.2 94.6 C38.4 95.8 35.4 97 32.4 98.8 C33 94 33.8 89.6 34.6 86 Z',
  ),
  (
    MuscleGroup.shoulders,
    'M31 33.4 C25.4 32.6 21 36.6 20.4 44.5 C20.2 49 21.2 52.4 22.6 55 C24.8 50.2 27.8 47 31.4 45 C31.6 41 31.4 37 31 33.4 Z',
  ),
  (
    MuscleGroup.triceps,
    'M29 50.2 C27 51 25 51.2 23.4 50.8 C22 57 21.6 64 22.4 71.4 C23.4 72 24.6 71.8 25.6 71.4 C27.4 64.4 28.8 57.4 29 50.2 Z',
  ),
  (
    MuscleGroup.triceps,
    'M23.4 50.8 C22 57 21.6 64 22.4 71.4 C20.8 71 19.4 70.2 18.2 69 C18.4 62 19.2 55 21 49.6 C21.8 50.2 22.6 50.6 23.4 50.8 Z',
  ),
  (
    MuscleGroup.forearms,
    'M25.4 73.6 C23.4 74 21.8 74 20.6 73.6 C19.6 81 18.2 90 17.2 99.4 L19.4 100 C21 91 23.8 82 25.4 75 Z',
  ),
  (
    MuscleGroup.forearms,
    'M20.6 73.6 C19.6 81 18.2 90 17.2 99.4 L14.8 98.6 C15.8 89 17 79 18.4 72.8 C19 73.2 19.8 73.4 20.6 73.6 Z',
  ),
  (
    MuscleGroup.glutes,
    'M49.4 96.6 C44 95 37.6 95.4 33 98.4 C31.6 106 32 114 34.4 120.2 C39 123.4 45.4 123.2 49.4 119.4 Z',
  ),
  (
    MuscleGroup.hamstrings,
    'M33.6 121.6 C33 132 34.6 141 37.6 149.4 C39 150 40.4 150.2 41.4 150.2 C42.2 141 42.2 132 41.4 124.2 C38.6 124 35.8 123 33.6 121.6 Z',
  ),
  (
    MuscleGroup.hamstrings,
    'M41.4 124.2 C44 124.4 46.6 123.2 48.8 121.4 C49.2 129 49.2 138 48.4 147.8 C46.4 149.6 43.8 150.2 41.4 150.2 C42.2 141 42.2 132 41.4 124.2 Z',
  ),
  (
    MuscleGroup.calves,
    'M35.2 159.4 C33.8 168 34.4 178 37.6 186.6 C39.2 186.8 40.6 186 41.6 184 C42 176 42 168 41.4 160 C39.6 158.6 37.2 158.4 35.2 159.4 Z',
  ),
  (
    MuscleGroup.calves,
    'M41.4 160 C43.2 158.4 45.6 158 47.8 158.4 C49 166 48.8 176 46.6 186 C44.6 187 42.8 186 41.6 184 C42 176 42 168 41.4 160 Z',
  ),
  (
    MuscleGroup.calves,
    'M37.8 187.4 C38.6 190.4 39.4 193.6 40.2 196.4 L44.6 196.4 C45.2 193 46 190 46.4 187.6 C44 189.2 40.8 189.2 37.8 187.4 Z',
  ),
];

/// Parses the M / L / C / Z subset of SVG path data used above.
Path _parsePath(String d) {
  final tokens = RegExp(r'[MLCZ]|-?\d*\.?\d+').allMatches(d).map((m) => m[0]!);
  final path = Path();
  String? cmd;
  final nums = <double>[];
  void flush() {
    switch (cmd) {
      case 'M':
        path.moveTo(nums[0], nums[1]);
      case 'L':
        for (var i = 0; i + 1 < nums.length; i += 2) {
          path.lineTo(nums[i], nums[i + 1]);
        }
      case 'C':
        for (var i = 0; i + 5 < nums.length; i += 6) {
          path.cubicTo(
            nums[i],
            nums[i + 1],
            nums[i + 2],
            nums[i + 3],
            nums[i + 4],
            nums[i + 5],
          );
        }
      case 'Z':
        path.close();
    }
    nums.clear();
  }

  for (final t in tokens) {
    if (t.length == 1 && 'MLCZ'.contains(t)) {
      if (cmd != null) flush();
      cmd = t;
    } else {
      nums.add(double.parse(t));
    }
  }
  flush();
  return path;
}

final _mirror = Float64List.fromList([
  -1, 0, 0, 0, //
  0, 1, 0, 0,
  0, 0, 1, 0,
  _designSize.width, 0, 0, 1,
]);

/// [half] plus its reflection across the centre line, as one path.
Path _symmetric(String half) {
  final p = _parsePath(half);
  return Path()
    ..addPath(p, Offset.zero)
    ..addPath(p.transform(_mirror), Offset.zero);
}

final _torso = _symmetric(_silhouette);
final _headPath = _parsePath(_head);
final _body = Path()
  ..addPath(_torso, Offset.zero)
  ..addPath(_headPath, Offset.zero);

final _parts = {
  BodyView.front: [
    for (final (m, d) in _front) BodyPart(_symmetric(d), muscle: m),
  ],
  BodyView.back: [
    for (final (m, d) in _back) BodyPart(_symmetric(d), muscle: m),
  ],
};

/// The whole figure outline (head, torso, limbs) for either view.
Path get bodyOutline => _body;

/// Muscle shapes for [view], in paint order. Public so tests can check that
/// every muscle group is drawn somewhere.
List<BodyPart> bodyParts(BodyView view) => _parts[view]!;

/// Front + back body diagram with [primary] in full colour and
/// [secondary] muscles in a lighter tint. Pair it with a text legend —
/// the diagram alone is colour-only information.
class MuscleMap extends StatelessWidget {
  const MuscleMap({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.height = 220,
    this.showLabels = true,
  });

  final MuscleGroup? primary;
  final List<MuscleGroup> secondary;
  final double height;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final names = [
      if (primary != null) primary!.label,
      ...secondary.map((m) => m.label),
    ];
    return Semantics(
      label: names.isEmpty
          ? 'Body diagram, no muscles selected'
          : 'Body diagram highlighting ${names.join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final view in BodyView.values) ...[
              if (view == BodyView.back) const SizedBox(width: AppSpacing.xl),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: height,
                    width: height * _designSize.width / _designSize.height,
                    child: CustomPaint(
                      painter: _MuscleMapPainter(view, primary, secondary),
                    ),
                  ),
                  if (showLabels) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      view == BodyView.front ? 'FRONT' : 'BACK',
                      style: AppText.overline,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter(this.view, this.primary, this.secondary);

  final BodyView view;
  final MuscleGroup? primary;
  final List<MuscleGroup> secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / _designSize.height;
    canvas.scale(s);

    final skin = Paint()..color = AppColors.surfaceHigh;
    canvas.drawPath(_torso, skin);

    // Thin seams in the body colour separate neighbouring muscles.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 0.7
      ..color = AppColors.surfaceHigh;
    final fill = Paint();

    for (final part in bodyParts(view)) {
      final m = part.muscle;
      fill.color = switch (m) {
        null => AppColors.outline,
        _ when m == primary => m.color,
        _ when secondary.contains(m) => m.color.withValues(alpha: 0.45),
        _ => AppColors.muscleIdle,
      };
      canvas
        ..drawPath(part.path, fill)
        ..drawPath(part.path, seam);
    }
    // Head last so neck seams don't cut across the chin.
    canvas.drawPath(_headPath, skin);
  }

  @override
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.view != view ||
      old.primary != primary ||
      old.secondary.length != secondary.length ||
      !old.secondary.every(secondary.contains);
}
