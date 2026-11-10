import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../data/day_card.dart';
import 'story_cards.dart';

/// A layout for the "Today" story card. Steps are always the hero; the
/// workout only appears on gym days and stays second.
///
/// To add a design: write a widget that takes [DayCardData] and an
/// optional background, then add a [TodayDesign] to [todayDesigns]. The
/// share screen picks it up automatically.
class TodayDesign {
  const TodayDesign({
    required this.id,
    required this.name,
    required this.builder,
  });

  /// Stable key (safe to store later as a preference).
  final String id;
  final String name;
  final Widget Function(DayCardData data, ImageProvider? background) builder;
}

final todayDesigns = <TodayDesign>[
  TodayDesign(
    id: 'hero',
    name: 'Hero',
    builder: (d, bg) => HeroStepsCard(data: d, background: bg),
  ),
  TodayDesign(
    id: 'ring',
    name: 'Ring',
    builder: (d, bg) => RingStepsCard(data: d, background: bg),
  ),
  TodayDesign(
    id: 'minimal',
    name: 'Minimal',
    builder: (d, bg) => MinimalStepsCard(data: d, background: bg),
  ),
  TodayDesign(
    id: 'split',
    name: 'Split',
    builder: (d, bg) => SplitStepsCard(data: d, background: bg),
  ),
  TodayDesign(
    id: 'tiles',
    name: 'Tiles',
    builder: (d, bg) => TilesStepsCard(data: d, background: bg),
  ),
  TodayDesign(
    id: 'year',
    name: 'Year',
    builder: (d, bg) => DayStoryCard(data: d, background: bg),
  ),
];

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

const _wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _mo = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

String _shortDay(DateTime d) =>
    '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

String _steps(DayCardData d) => d.steps == null ? '—' : thousands(d.steps!);

String? _km(DayCardData d) {
  final km = d.distanceKm;
  if (km == null || km < 0.05) return null;
  return '≈ ${km.toStringAsFixed(1)} km';
}

/// "52 min · 18 sets · 6 exercises" — whatever is known.
String _workoutMeta(DayCardData d) {
  final parts = <String>[
    if ((d.workoutMinutes ?? 0) > 0)
      formatDuration(Duration(minutes: d.workoutMinutes!)),
    if (d.workoutSets > 0)
      '${d.workoutSets} ${d.workoutSets == 1 ? 'set' : 'sets'}',
    if (d.exercises.isNotEmpty)
      '${d.exercises.length} ${d.exercises.length == 1 ? 'exercise' : 'exercises'}',
  ];
  return parts.isEmpty ? 'Workout done' : parts.join(' · ');
}

/// How a background photo is darkened so the text reads on it.
enum _Shade {
  /// Light at the top, almost black at the bottom (text sits low).
  bottom,

  /// Darkened all over (text spread through the card).
  even,

  /// Lighter all over, for centred text on a photo that should show.
  soft,
}

/// 9:16 canvas: a background photo under a dark fade, or pure black with
/// soft colour glows when there's no photo. Text scaling is fixed so the
/// shared image looks the same on every phone.
class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.background,
    required this.child,
    this.shade = _Shade.bottom,
  });

  final ImageProvider? background;
  final Widget child;
  final _Shade shade;

  @override
  Widget build(BuildContext context) {
    final bg = background;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: storySize,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bg != null) ...[
                Image(image: bg, fit: BoxFit.cover, gaplessPlayback: true),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: switch (shade) {
                      _Shade.bottom => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.22, 0.45, 0.68, 1],
                        colors: [
                          Color(0xA6000000),
                          Color(0x26000000),
                          Color(0x1A000000),
                          Color(0xC7000000),
                          Color(0xF7000000),
                        ],
                      ),
                      _Shade.soft => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.3, 0.6, 1],
                        colors: [
                          Color(0x99000000),
                          Color(0x59000000),
                          Color(0x73000000),
                          Color(0xD9000000),
                        ],
                      ),
                      _Shade.even => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.5, 1],
                        colors: [
                          Color(0xB3000000),
                          Color(0x99000000),
                          Color(0xE6000000),
                        ],
                      ),
                    },
                  ),
                ),
              ] else ...[
                const Positioned(
                  top: -120,
                  right: -100,
                  child: _Glow(color: AppColors.steps, size: 380),
                ),
                const Positioned(
                  bottom: -140,
                  left: -120,
                  child: _Glow(color: AppColors.time, size: 340),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.progress, this.height = 6, this.width});
  final double progress;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: height,
          color: AppColors.steps,
          backgroundColor: Colors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

const _small = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: AppColors.textSecondary,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// "62% of 10,000 · ≈ 5.1 km" and the streak, under a steps number.
class _StepsMeta extends StatelessWidget {
  const _StepsMeta({
    required this.data,
    this.center = false,
    this.showKm = true,
    this.showStreak = true,
  });
  final DayCardData data;
  final bool center;
  final bool showKm;
  final bool showStreak;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final pct = (d.stepsProgress * 100).round();
    final km = showKm ? _km(d) : null;
    final left = d.steps == null
        ? 'Goal ${thousands(d.stepsGoal)}'
        : d.stepsOk
        ? 'Goal ${thousands(d.stepsGoal)} reached'
        : '$pct% of ${thousands(d.stepsGoal)}';
    final children = <Widget>[
      if (d.stepsOk) ...[
        const Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: AppColors.steps,
        ),
        const SizedBox(width: 4),
      ],
      Flexible(
        child: Text(
          km == null ? left : '$left  ·  $km',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _small,
        ),
      ),
      if (!center) const Spacer() else const SizedBox(width: 12),
      if (showStreak && d.streak >= 2) ...[
        const Icon(
          Icons.local_fire_department_rounded,
          size: 14,
          color: AppColors.accent,
        ),
        const SizedBox(width: 3),
        Text(
          '${d.streak}-day streak',
          style: _small.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ];
    return Row(
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: children,
    );
  }
}

/// Orange dumbbell badge + workout name + "52 min · 18 sets".
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.data, this.badge = 34});
  final DayCardData data;
  final double badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: badge,
          height: badge,
          decoration: const BoxDecoration(
            color: AppColors.workouts,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            size: badge * 0.52,
            color: AppColors.onAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.workoutName!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _workoutMeta(data),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's exercises, one line each, with the set summary on the right.
class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.data, this.max = 4, this.indent = 0});
  final DayCardData data;
  final int max;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final list = data.exercises;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in list.take(max))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      e.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (list.length > max)
            Text(
              '+ ${list.length - max} more',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Last 7 days of steps as bars with the goal as a line. Days at goal
/// get a tick above the bar, so it doesn't rely on colour alone.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.data, this.height = 64});
  final DayCardData data;
  final double height;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final steps = data.stepsWeek!;
    final goal = data.stepsGoal;
    final top = [goal, ...steps].reduce((a, b) => a > b ? a : b) * 1.12;
    final today = DateTime(data.date.year, data.date.month, data.date.day);
    final n = steps.length;
    // Fixed slots: tick (12) · bars (height) · gap (4) · day letter (14).
    return SizedBox(
      height: height + 30,
      child: Stack(
        children: [
          if (goal > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 12 + height - height * goal / top,
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 12,
                        child: goal > 0 && steps[i] >= goal
                            ? const Icon(
                                Icons.check_rounded,
                                size: 10,
                                color: AppColors.textPrimary,
                              )
                            : null,
                      ),
                      SizedBox(
                        height: height,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 14,
                            height: (height * steps[i] / top).clamp(
                              3.0,
                              height,
                            ),
                            decoration: BoxDecoration(
                              color: goal > 0 && steps[i] >= goal
                                  ? AppColors.steps
                                  : Colors.white.withValues(
                                      alpha: i == n - 1 ? 0.55 : 0.26,
                                    ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 14,
                        child: Text(
                          _letters[today
                                  .subtract(Duration(days: n - 1 - i))
                                  .weekday -
                              1],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: i == n - 1
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: i == n - 1
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text, {this.color = AppColors.steps, this.spacing = 4});
  final String text;
  final Color color;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: spacing,
        color: color,
      ),
    );
  }
}

/// A steps number that shrinks to fit its line.
class _BigNumber extends StatelessWidget {
  const _BigNumber(
    this.text, {
    required this.size,
    this.weight = FontWeight.w900,
    this.alignment = Alignment.centerLeft,
    this.suffix,
  });
  final String text;
  final double size;
  final FontWeight weight;
  final Alignment alignment;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text,
              style: TextStyle(
                fontSize: size,
                height: 0.95,
                fontWeight: weight,
                letterSpacing: -size * 0.04,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (suffix != null)
              TextSpan(
                text: suffix,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}

/// Dark rounded panel used on photo cards.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = 16});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0D).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Designs
// ---------------------------------------------------------------------------

/// Photo-first: a giant steps number at the bottom, the workout as a
/// small badge above it on gym days.
class HeroStepsCard extends StatelessWidget {
  const HeroStepsCard({super.key, required this.data, this.background});
  final DayCardData data;
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return _Canvas(
      background: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoryBrand(right: _shortDay(d.date)),
          const Spacer(),
          if (!d.isRestDay) ...[
            _Panel(padding: 12, child: _WorkoutRow(data: d)),
            const SizedBox(height: 22),
          ],
          const _Overline('STEPS TODAY'),
          const SizedBox(height: 4),
          _BigNumber(_steps(d), size: 108),
          const SizedBox(height: 12),
          _Bar(progress: d.stepsProgress),
          const SizedBox(height: 8),
          _StepsMeta(data: d),
          const SizedBox(height: 18),
          const StoryFooter(),
        ],
      ),
    );
  }
}

/// One big steps ring; below it the workout (gym day) or the last
/// 7 days of steps (rest day).
class RingStepsCard extends StatelessWidget {
  const RingStepsCard({super.key, required this.data, this.background});
  final DayCardData data;
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return _Canvas(
      background: background,
      shade: _Shade.even,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoryBrand(right: _shortDay(d.date)),
          const SizedBox(height: 28),
          Center(
            child: SizedBox.square(
              dimension: 236,
              child: CustomPaint(
                painter: _RingPainter(progress: d.stepsProgress),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_walk_rounded,
                        color: AppColors.steps,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 160,
                        child: _BigNumber(
                          _steps(d),
                          size: 50,
                          alignment: Alignment.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('of ${thousands(d.stepsGoal)} steps', style: _small),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _StepsMeta(data: d, center: true),
          const Spacer(),
          if (!d.isRestDay)
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WorkoutRow(data: d, badge: 30),
                  if (d.exercises.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ExerciseList(data: d, max: 4, indent: 40),
                  ],
                ],
              ),
            )
          else if (d.stepsWeek != null && d.stepsWeek!.length > 1)
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Overline(
                    'LAST 7 DAYS',
                    color: AppColors.textSecondary,
                    spacing: 1.5,
                  ),
                  const SizedBox(height: 10),
                  _WeekBars(data: d),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const StoryFooter(),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});
  final double progress;

  static const _stroke = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = AppColors.steps.withValues(alpha: 0.18);
    canvas.drawArc(rect, 0, 6.2832, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: [Color(0xFFFF7A1A), AppColors.steps],
        transform: GradientRotation(-1.5708),
      ).createShader(rect);
    canvas.drawArc(rect, -1.5708, 6.2832 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// Quiet and centred: thin numbers over the photo, the workout as one
/// line underneath.
class MinimalStepsCard extends StatelessWidget {
  const MinimalStepsCard({super.key, required this.data, this.background});
  final DayCardData data;
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final km = _km(d);
    return _Canvas(
      background: background,
      shade: _Shade.soft,
      child: Column(
        children: [
          const Text(
            'LOCK-IN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _shortDay(d.date),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 3),
          _BigNumber(
            _steps(d),
            size: 92,
            weight: FontWeight.w300,
            alignment: Alignment.center,
          ),
          const SizedBox(height: 8),
          const _Overline('STEPS', spacing: 8),
          const SizedBox(height: 16),
          _Bar(progress: d.stepsProgress, height: 4, width: 140),
          const SizedBox(height: 10),
          Text(
            [
              if (d.stepsOk)
                'Goal reached'
              else
                '${(d.stepsProgress * 100).round()}% of goal',
              ?km,
              if (d.streak >= 2) '${d.streak}-day streak',
            ].join('  ·  '),
            style: _small,
          ),
          if (!d.isRestDay) ...[
            const SizedBox(height: 34),
            Container(
              width: 28,
              height: 2,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  size: 16,
                  color: AppColors.workouts,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    d.workoutName!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_workoutMeta(d), style: _small),
          ],
          const Spacer(flex: 4),
          const StoryFooter(),
        ],
      ),
    );
  }
}

/// Photo on top, steps (and the workout) on a black panel below.
class SplitStepsCard extends StatelessWidget {
  const SplitStepsCard({super.key, required this.data, this.background});
  final DayCardData data;
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final bg = background;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: storySize,
        child: ColoredBox(
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bg != null)
                      Image(image: bg, fit: BoxFit.cover, gaplessPlayback: true)
                    else
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF4D6D), Color(0xFF7A1FFF)],
                          ),
                        ),
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.3, 0.75, 1],
                          colors: [
                            Color(0x99000000),
                            Color(0x00000000),
                            Color(0x33000000),
                            Color(0xFF000000),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: StoryBrand(right: _shortDay(d.date)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _BigNumber(
                            _steps(d),
                            size: 64,
                            suffix: '  steps',
                          ),
                        ),
                        StoryCheck(done: d.stepsOk, color: AppColors.steps),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Bar(progress: d.stepsProgress),
                    const SizedBox(height: 8),
                    _StepsMeta(data: d),
                    if (!d.isRestDay) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      const SizedBox(height: 14),
                      _WorkoutRow(data: d, badge: 30),
                      if (d.exercises.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Text(
                            d.exercises.map((e) => e.name).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    const StoryFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fitness-band dashboard: a big steps tile with the week, then small
/// tiles for the workout (gym day) or streak and distance (rest day),
/// protein and calories.
class TilesStepsCard extends StatelessWidget {
  const TilesStepsCard({super.key, required this.data, this.background});
  final DayCardData data;
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final km = d.distanceKm;
    return _Canvas(
      background: background,
      shade: _Shade.even,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoryBrand(right: _shortDay(d.date)),
          const Spacer(),
          _Panel(
            padding: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TileLabel(
                  icon: Icons.directions_walk_rounded,
                  color: AppColors.steps,
                  label: 'Steps',
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _BigNumber(_steps(d), size: 60)),
                    StoryCheck(done: d.stepsOk, color: AppColors.steps),
                  ],
                ),
                const SizedBox(height: 10),
                _Bar(progress: d.stepsProgress),
                const SizedBox(height: 8),
                // Narrow panel: distance is left out (it has its own tile
                // on rest days), and so is the streak on rest days.
                _StepsMeta(data: d, showKm: false, showStreak: !d.isRestDay),
                if (d.stepsWeek != null && d.stepsWeek!.length > 1) ...[
                  const SizedBox(height: 14),
                  _WeekBars(data: d, height: 56),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!d.isRestDay)
            _Panel(padding: 14, child: _WorkoutRow(data: d, badge: 30))
          else
            Row(
              children: [
                Expanded(
                  child: _SmallTile(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.accent,
                    label: 'Streak',
                    value: '${d.streak}',
                    unit: d.streak == 1 ? 'day' : 'days',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SmallTile(
                    icon: Icons.route_rounded,
                    color: AppColors.body,
                    label: 'Distance',
                    value: km == null ? '—' : '≈ ${km.toStringAsFixed(1)}',
                    unit: km == null ? null : 'km',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallTile(
                  icon: Icons.egg_alt_rounded,
                  color: AppColors.protein,
                  label: 'Protein',
                  value: '${d.proteinG}',
                  unit: 'g',
                  done: d.proteinOk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallTile(
                  icon: Icons.restaurant_rounded,
                  color: AppColors.food,
                  label: 'Calories',
                  value: d.kcal == 0 ? '—' : thousands(d.kcal),
                  unit: d.kcal == 0 ? null : 'kcal',
                  done: d.kcalOk,
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
          const StoryFooter(),
        ],
      ),
    );
  }
}

class _TileLabel extends StatelessWidget {
  const _TileLabel({
    required this.icon,
    required this.color,
    required this.label,
    this.done = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (done) Icon(Icons.check_circle_rounded, size: 14, color: color),
      ],
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit,
    this.done = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileLabel(icon: icon, color: color, label: label, done: done),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
