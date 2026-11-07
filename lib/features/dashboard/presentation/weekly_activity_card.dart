import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../data/week_summary.dart';

String _grouped(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// Band-style weekly summary: pace against the workout goal, three activity
/// rings (workouts, minutes, working sets) with the change since the same
/// point last week, a Mon–Sun strip showing what was trained, and
/// highlights (volume, best lift, streak).
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({
    super.key,
    required this.summary,
    required this.unit,
    this.streak = 0,
    this.workoutGoal = 3,
    this.minutesGoal = 180,
    this.setsGoal = 45,
    this.onEditGoals,
    this.onOpenWorkout,
  });

  final WeekSummary summary;
  final WeightUnit unit;
  final int streak;
  final int workoutGoal;
  final int minutesGoal;
  final int setsGoal;
  final VoidCallback? onEditGoals;
  final ValueChanged<int>? onOpenWorkout;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final week = summary.thisWeek;
    final last = summary.lastWeekSoFar;
    final today = summary.now.weekday;
    final hasHistory = summary.lastWeekTotal > 0 || last.workouts > 0;
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;

    double ratio(int value, int goal) => goal <= 0 ? 0 : value / goal;
    int? delta(int now, int before) => hasHistory ? now - before : null;

    final maxMinutes = summary.days.fold<int>(
      90,
      (m, d) => d.minutes > m ? d.minutes : m,
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaceRow(
            pace: weekPace(
              workouts: week.workouts,
              goal: workoutGoal,
              now: summary.now,
            ),
            goal: workoutGoal,
            workouts: week.workouts,
            lastWeekTotal: summary.lastWeekTotal,
            streak: streak,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            button: onEditGoals != null,
            hint: onEditGoals == null ? null : 'Change weekly goals',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              onTap: onEditGoals,
              child: Row(
                children: [
                  ActivityRings(
                    size: 132,
                    strokeWidth: 13,
                    semanticsLabel:
                        '${week.workouts} of $workoutGoal workouts, '
                        '${week.minutes} of $minutesGoal minutes, '
                        '${week.sets} of $setsGoal sets this week',
                    rings: [
                      RingData(
                        progress: ratio(week.workouts, workoutGoal),
                        color: AppColors.workouts,
                      ),
                      RingData(
                        progress: ratio(week.minutes, minutesGoal),
                        color: AppColors.time,
                      ),
                      RingData(
                        progress: ratio(week.sets, setsGoal),
                        color: AppColors.sets,
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RingLegend(
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.workouts,
                          value: '${week.workouts}',
                          goal: '/$workoutGoal',
                          label: 'Workouts',
                          delta: delta(week.workouts, last.workouts),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RingLegend(
                          icon: Icons.timer_rounded,
                          color: AppColors.time,
                          value: '${week.minutes}',
                          goal: '/$minutesGoal min',
                          label: 'Active time',
                          delta: delta(week.minutes, last.minutes),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RingLegend(
                          icon: Icons.layers_rounded,
                          color: AppColors.sets,
                          value: '${week.sets}',
                          goal: '/$setsGoal',
                          label: 'Working sets',
                          delta: delta(week.sets, last.sets),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var day = 1; day <= 7; day++) ...[
                if (day > 1) const SizedBox(width: 6),
                Expanded(
                  child: _DayColumn(
                    letter: _dayLetters[day - 1],
                    name: _dayNames[day - 1],
                    activity: summary.days[day - 1],
                    maxMinutes: maxMinutes,
                    isToday: day == today,
                    isFuture: day > today,
                    showMinutes: textScale <= 1.3,
                    onTap:
                        onOpenWorkout == null || !summary.days[day - 1].trained
                        ? null
                        : () => onOpenWorkout!(
                            summary.days[day - 1].workoutIds.first,
                          ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),
          _Highlights(
            summary: summary,
            unit: unit,
            streak: streak,
            stacked: textScale > 1.3,
          ),
          if (onEditGoals != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tap the rings to change weekly goals',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaceRow extends StatelessWidget {
  const _PaceRow({
    required this.pace,
    required this.goal,
    required this.workouts,
    required this.lastWeekTotal,
    required this.streak,
  });

  final WeekPace pace;
  final int goal;
  final int workouts;
  final int lastWeekTotal;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final days = pace.daysLeft == 1 ? 'last day' : '${pace.daysLeft} days left';
    final (icon, label, fg, bg, detail) = switch (pace.state) {
      WeekPaceState.goalHit => (
        Icons.check_rounded,
        'Goal hit',
        AppColors.onAccent,
        AppColors.sets,
        streak > 1
            ? '$workouts of $goal · $streak-week streak'
            : '$workouts of $goal this week',
      ),
      WeekPaceState.newWeek => (
        Icons.calendar_today_rounded,
        'New week',
        AppColors.textPrimary,
        AppColors.surfaceHigh,
        lastWeekTotal > 0
            ? '$goal to go · last week $lastWeekTotal'
            : '$goal to go · $days',
      ),
      WeekPaceState.behind => (
        Icons.warning_rounded,
        '${pace.behindBy} behind',
        AppColors.warning,
        AppColors.warning.withValues(alpha: 0.16),
        '${pace.toGo} more to hit $goal · $days',
      ),
      WeekPaceState.onTrack => (
        Icons.trending_up_rounded,
        'On track',
        AppColors.sets,
        AppColors.sets.withValues(alpha: 0.16),
        '${pace.toGo} more to hit $goal · $days',
      ),
    };

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        Text(
          detail,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// An up/down arrow drawn as an icon, so it never depends on the font
/// having a ▲ glyph. The number next to it carries the screen-reader text.
InlineSpan _arrowSpan({required bool up}) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: ExcludeSemantics(
    child: Icon(
      up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      size: 12,
      color: up ? AppColors.textPrimary : AppColors.textSecondary,
    ),
  ),
);

class _RingLegend extends StatelessWidget {
  const _RingLegend({
    required this.icon,
    required this.color,
    required this.value,
    required this.goal,
    required this.label,
    this.delta,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String goal;
  final String label;

  /// Change since the same point last week; null hides it.
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AppColors.textSecondary);
    final d = delta;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: AppText.metricM.copyWith(color: color),
                    ),
                    TextSpan(text: goal, style: AppText.unit),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    if (d != null && d != 0) ...[
                      const TextSpan(text: '  '),
                      _arrowSpan(up: d > 0),
                      TextSpan(
                        text: '${d.abs()}',
                        semanticsLabel:
                            ', ${d > 0 ? 'up' : 'down'} ${d.abs()} on last week',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: d > 0
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                style: small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.letter,
    required this.name,
    required this.activity,
    required this.maxMinutes,
    required this.isToday,
    required this.isFuture,
    required this.showMinutes,
    this.onTap,
  });

  final String letter;
  final String name;
  final DayActivity activity;
  final int maxMinutes;
  final bool isToday;
  final bool isFuture;
  final bool showMinutes;
  final VoidCallback? onTap;

  static const _barHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final region = dominantRegion(activity.muscleSets);
    final fill = region?.color ?? AppColors.workouts;
    final trained = activity.trained;
    final small = TextStyle(
      fontSize: 10,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: region?.color ?? AppColors.textSecondary,
    );

    return Semantics(
      button: onTap != null,
      label: trained
          ? '$name, ${region?.label ?? 'trained'}, ${activity.minutes} minutes'
          : isFuture
          ? name
          : '$name, rest',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          children: [
            if (showMinutes)
              Text(
                trained ? '${activity.minutes}m' : '',
                maxLines: 1,
                style: small.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            const SizedBox(height: 2),
            Container(
              height: _barHeight,
              constraints: const BoxConstraints(maxWidth: 30),
              decoration: BoxDecoration(
                color: isFuture
                    ? AppColors.surfaceHigh.withValues(alpha: 0.55)
                    : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(9),
                border: isToday
                    ? Border.all(color: AppColors.workouts, width: 2)
                    : null,
              ),
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.antiAlias,
              child: trained
                  ? AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      heightFactor: (activity.minutes / maxMinutes).clamp(
                        0.35,
                        1.0,
                      ),
                      widthFactor: 1,
                      child: Container(
                        color: fill,
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 3),
                        // A tick as well as colour, so state isn't colour-only.
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: AppColors.onAccent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(region?.label ?? '', maxLines: 1, style: small),
            ),
            Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? AppColors.textPrimary
                    : isFuture
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({
    required this.summary,
    required this.unit,
    required this.streak,
    required this.stacked,
  });

  final WeekSummary summary;
  final WeightUnit unit;
  final int streak;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final volume = kgToDisplay(summary.thisWeek.volumeKg, unit).round();
    final change = summary.volumeChange;
    final lift = summary.topLift;

    final items = [
      _Highlight(
        icon: Icons.bar_chart_rounded,
        color: AppColors.volume,
        label: 'Volume',
        value: volume == 0 ? '—' : _grouped(volume),
        unit: volume == 0 ? null : unitLabel(unit),
        caption: change == null
            ? (volume == 0 ? 'no lifts yet' : 'this week')
            : change == 0
            ? 'same as last wk'
            : '${(change.abs() * 100).round()}% vs last wk',
        captionSemantics: change == null || change == 0
            ? null
            : '${change > 0 ? 'up' : 'down'} '
                  '${(change.abs() * 100).round()}% on last week',
        trendUp: change == null || change == 0 ? null : change > 0,
      ),
      _Highlight(
        icon: Icons.emoji_events_rounded,
        color: AppColors.records,
        label: 'Best lift',
        value: lift == null
            ? '—'
            : formatNumber((kgToDisplay(lift.e1rmKg, unit) * 2).round() / 2),
        unit: lift == null ? null : unitLabel(unit),
        caption: lift == null ? 'est. 1-rep max' : '${lift.exercise} e1RM',
      ),
      _Highlight(
        icon: Icons.local_fire_department_rounded,
        color: AppColors.streak,
        label: 'Streak',
        value: '$streak',
        unit: streak == 1 ? 'wk' : 'wks',
        caption: streak == 0 ? 'hit your goal to start' : 'goal hit in a row',
      ),
    ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            item,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: item),
        ],
      ],
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
    this.unit,
    this.trendUp,
    this.captionSemantics,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;
  final String caption;

  /// Shows an up (true) or down (false) arrow before [caption].
  final bool? trendUp;
  final String? captionSemantics;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppText.metricM.copyWith(fontSize: 18),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: AppText.unit.copyWith(fontSize: 12),
                  ),
              ],
            ),
            maxLines: 1,
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              if (trendUp != null) ...[
                _arrowSpan(up: trendUp!),
                const TextSpan(text: ' '),
              ],
              TextSpan(text: caption, semanticsLabel: captionSemantics),
            ],
          ),
          style: small?.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
