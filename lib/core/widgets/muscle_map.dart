import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/muscle_style.dart';
import '../database/enums.dart';

enum BodyView { front, back }

/// A shape on the body diagram, in a 100 × 220 design space.
/// [muscle] null = non-muscle body part (head, hands, joints), always neutral.
class BodyRegion {
  const BodyRegion(
    this.rect, {
    this.muscle,
    this.radius = 6,
    this.oval = false,
  });
  final Rect rect;
  final MuscleGroup? muscle;
  final double radius;
  final bool oval;

  /// The same region reflected across the body's centre line.
  BodyRegion mirrored() => BodyRegion(
    Rect.fromLTRB(100 - rect.right, rect.top, 100 - rect.left, rect.bottom),
    muscle: muscle,
    radius: radius,
    oval: oval,
  );
}

const _designSize = Size(100, 220);

List<BodyRegion> _symmetric(List<BodyRegion> leftSide) => [
  for (final r in leftSide) ...[r, r.mirrored()],
];

/// Body diagram regions for [view]. Public so tests can check that every
/// muscle group is drawn somewhere.
List<BodyRegion> bodyRegions(BodyView view) {
  final shared = <BodyRegion>[
    const BodyRegion(Rect.fromLTRB(40, 2, 60, 24), oval: true), // head
    const BodyRegion(Rect.fromLTRB(45, 22, 55, 32), radius: 3), // neck
    ..._symmetric(const [
      BodyRegion(Rect.fromLTRB(14, 96, 24, 108), oval: true), // hand
      BodyRegion(Rect.fromLTRB(37, 148, 48, 156), radius: 4), // knee
      BodyRegion(Rect.fromLTRB(36, 196, 48, 206), radius: 4), // foot
      BodyRegion(
        Rect.fromLTRB(15, 70, 26, 96),
        muscle: MuscleGroup.forearms,
        radius: 5,
      ),
      BodyRegion(
        Rect.fromLTRB(23, 32, 40, 48),
        muscle: MuscleGroup.shoulders,
        oval: true,
      ),
    ]),
  ];

  switch (view) {
    case BodyView.front:
      return [
        ...shared,
        ..._symmetric(const [
          BodyRegion(
            Rect.fromLTRB(33.5, 34, 49, 54),
            muscle: MuscleGroup.chest,
            radius: 7,
          ),
          BodyRegion(
            Rect.fromLTRB(19, 48, 30, 69),
            muscle: MuscleGroup.biceps,
            radius: 6,
          ),
          BodyRegion(
            Rect.fromLTRB(34, 57, 41, 90),
            muscle: MuscleGroup.core,
            radius: 4,
          ),
          BodyRegion(
            Rect.fromLTRB(42.5, 56, 49, 66),
            muscle: MuscleGroup.abs,
            radius: 3,
          ),
          BodyRegion(
            Rect.fromLTRB(42.5, 68, 49, 78),
            muscle: MuscleGroup.abs,
            radius: 3,
          ),
          BodyRegion(
            Rect.fromLTRB(42.5, 80, 49, 91),
            muscle: MuscleGroup.abs,
            radius: 3,
          ),
          BodyRegion(
            Rect.fromLTRB(35, 98, 49, 146),
            muscle: MuscleGroup.quadriceps,
            radius: 8,
          ),
          BodyRegion(Rect.fromLTRB(38, 158, 47, 194), radius: 5), // shin
        ]),
        const BodyRegion(Rect.fromLTRB(36, 92, 64, 100), radius: 4), // hips
      ];
    case BodyView.back:
      return [
        ...shared,
        const BodyRegion(
          Rect.fromLTRB(39, 28, 61, 42),
          muscle: MuscleGroup.back,
          radius: 7,
        ), // traps
        ..._symmetric(const [
          BodyRegion(
            Rect.fromLTRB(33.5, 43, 49, 74),
            muscle: MuscleGroup.back,
            radius: 8,
          ), // lats
          BodyRegion(
            Rect.fromLTRB(42.5, 76, 49, 91),
            muscle: MuscleGroup.back,
            radius: 4,
          ), // lower back
          BodyRegion(
            Rect.fromLTRB(19, 48, 30, 69),
            muscle: MuscleGroup.triceps,
            radius: 6,
          ),
          BodyRegion(
            Rect.fromLTRB(34, 76, 41, 90),
            muscle: MuscleGroup.core,
            radius: 4,
          ), // obliques from behind
          BodyRegion(
            Rect.fromLTRB(35, 93, 49, 115),
            muscle: MuscleGroup.glutes,
            radius: 10,
          ),
          BodyRegion(
            Rect.fromLTRB(35, 117, 49, 146),
            muscle: MuscleGroup.hamstrings,
            radius: 8,
          ),
          BodyRegion(
            Rect.fromLTRB(37, 158, 48, 192),
            muscle: MuscleGroup.calves,
            oval: true,
          ),
        ]),
      ];
  }
}

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

    final neutral = Paint()..color = AppColors.surfaceHigh;
    final idleMuscle = Paint()..color = const Color(0xFF2A2A31);

    for (final region in bodyRegions(view)) {
      final m = region.muscle;
      final Paint paint;
      if (m == null) {
        paint = neutral;
      } else if (m == primary) {
        paint = Paint()..color = m.color;
      } else if (secondary.contains(m)) {
        paint = Paint()..color = m.color.withValues(alpha: 0.45);
      } else {
        paint = idleMuscle;
      }
      if (region.oval) {
        canvas.drawOval(region.rect, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(region.rect, Radius.circular(region.radius)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.view != view ||
      old.primary != primary ||
      old.secondary.length != secondary.length ||
      !old.secondary.every(secondary.contains);
}
