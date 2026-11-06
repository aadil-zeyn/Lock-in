import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../body/data/body_repository.dart';
import '../../body/presentation/log_weight_sheet.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/stats.dart';
import '../data/stats_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit =
        ref.watch(userProfileProvider).value?.weightUnit ?? WeightUnit.kg;
    return TabPage(
      title: 'Progress',
      children: [
        const SizedBox(height: AppSpacing.lg),
        _WeightSection(unit: unit),
        const SectionHeader('Training'),
        const _TrainingCard(),
        const SectionHeader('Strength'),
        _StrengthSection(unit: unit),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Body weight
// ---------------------------------------------------------------------------

class _WeightSection extends ConsumerStatefulWidget {
  const _WeightSection({required this.unit});
  final WeightUnit unit;

  @override
  ConsumerState<_WeightSection> createState() => _WeightSectionState();
}

class _WeightSectionState extends ConsumerState<_WeightSection> {
  ChartRange _range = ChartRange.quarter;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final text = Theme.of(context).textTheme;
    final all = ref.watch(weightPointsProvider).value ?? const <ChartPoint>[];

    if (all.isEmpty) {
      return EmptyState(
        compact: true,
        icon: Icons.monitor_weight_outlined,
        title: 'Track your body weight',
        message:
            'Log a weigh-in now and then, or connect Health Connect to pull '
            'in your scale and Mi Fitness history.',
        actionLabel: 'Log weight',
        onAction: () => showLogWeightSheet(context),
      );
    }

    // Convert to the display unit once; the chart never sees kg.
    final shown = [for (final p in all) (x: p.x, y: kgToDisplay(p.y, unit))];
    final points = inRange(shown, _range.since(DateTime.now()));
    final trend = movingAverage(shown);
    final trendInRange = inRange(trend, _range.since(DateTime.now()));
    final summary = summarize(points);
    final label = unitLabel(unit);
    String fmt(double v) => formatNumber(double.parse(v.toStringAsFixed(1)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBadge(
                    icon: Icons.monitor_weight_rounded,
                    color: AppColors.body,
                    size: 36,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Body weight', style: text.titleSmall),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: fmt(shown.last.y),
                                style: AppText.metricL,
                              ),
                              TextSpan(text: ' $label', style: AppText.unit),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (summary != null && summary.count > 1)
                    _ChangeChip(
                      change: summary.change,
                      label: label,
                      range: _range,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final r in ChartRange.values)
                    SelectChip(
                      label: r.label,
                      selected: _range == r,
                      color: AppColors.body,
                      onTap: () => setState(() => _range = r),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (points.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'No weigh-ins in this range. Try a longer one.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                TimeLineChart(
                  points: points,
                  trend: trendInRange.length > 1 ? trendInRange : null,
                  color: AppColors.body,
                  formatValue: (v) => '${fmt(v)} $label',
                  pointsLabel: 'Weigh-ins',
                  trendLabel: '7-day average',
                  semanticsLabel:
                      'Body weight chart, ${points.length} entries, latest '
                      '${fmt(points.last.y)} $label',
                ),
              if (summary != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _MiniStat(
                      label: 'Lowest',
                      value: '${fmt(summary.min)} $label',
                    ),
                    _MiniStat(
                      label: 'Highest',
                      value: '${fmt(summary.max)} $label',
                    ),
                    _MiniStat(label: 'Entries', value: '${summary.count}'),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Log weight',
                icon: Icons.add_rounded,
                onPressed: () => showLogWeightSheet(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // The table view: every value in the chart is reachable as text.
        _WeightLog(
          unit: unit,
          showAll: _showAll,
          onToggle: () => setState(() => _showAll = !_showAll),
        ),
      ],
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({
    required this.change,
    required this.label,
    required this.range,
  });
  final double change;
  final String label;
  final ChartRange range;

  @override
  Widget build(BuildContext context) {
    final rounded = double.parse(change.toStringAsFixed(1));
    final icon = rounded > 0
        ? Icons.trending_up_rounded
        : rounded < 0
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final sign = rounded > 0
        ? '+'
        : rounded < 0
        ? '−'
        : '±';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '$sign${formatNumber(rounded.abs())} $label',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Text(
            range == ChartRange.all ? 'overall' : 'in ${range.label}',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.overline),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightLog extends ConsumerWidget {
  const _WeightLog({
    required this.unit,
    required this.showAll,
    required this.onToggle,
  });
  final WeightUnit unit;
  final bool showAll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(bodyWeightHistoryProvider).value ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();
    final visible = showAll ? rows : rows.take(5).toList();
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(indent: AppSpacing.lg),
            ListTile(
              dense: true,
              title: Text(
                '${formatNumber(double.parse(kgToDisplay(visible[i].measuredValue, unit).toStringAsFixed(1)))} ${unitLabel(unit)}',
                style: text.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              subtitle: Text(
                '${formatLongDate(visible[i].recordedAt)} ${visible[i].recordedAt.year}',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              trailing: IconButton(
                tooltip: 'Delete entry',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: () => _confirmDelete(context, ref, visible[i]),
              ),
            ),
          ],
          if (rows.length > 5)
            TextButton(
              onPressed: onToggle,
              child: Text(showAll ? 'Show less' : 'Show all ${rows.length}'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BodyMeasurement m,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this weigh-in?'),
        content: Text(
          '${formatLongDate(m.recordedAt)} ${m.recordedAt.year}. If it came '
          'from Health Connect it may sync back; delete it there too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(bodyRepositoryProvider).deleteMeasurement(m.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Training
// ---------------------------------------------------------------------------

class _TrainingCard extends ConsumerWidget {
  const _TrainingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(weeklyTrainingProvider).value;
    final text = Theme.of(context).textTheme;
    if (weeks == null) return const SizedBox(height: 160);
    final total = weeks.fold<int>(0, (n, w) => n + w.workouts);
    final minutes = weeks.fold<int>(0, (n, w) => n + w.minutes);

    if (total == 0) {
      return const EmptyState(
        compact: true,
        icon: Icons.bar_chart_rounded,
        title: 'No workouts in the last 8 weeks',
        message: 'Finish a workout, or import your history from Profile.',
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.workouts,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Workouts per week', style: text.titleSmall),
              ),
              Text(
                '$total in 8 wks · ${formatDuration(Duration(minutes: minutes))}',
                style: AppText.unit,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          WeekBars(
            values: [for (final w in weeks) w.workouts],
            labels: [
              for (var i = 0; i < weeks.length; i++)
                i == weeks.length - 1
                    ? 'This wk'
                    : formatShortDate(weeks[i].weekStart),
            ],
            color: AppColors.workouts,
            semanticsLabel:
                'Workouts per week for 8 weeks: '
                '${weeks.map((w) => w.workouts).join(', ')}',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strength
// ---------------------------------------------------------------------------

class _StrengthSection extends ConsumerStatefulWidget {
  const _StrengthSection({required this.unit});
  final WeightUnit unit;

  @override
  ConsumerState<_StrengthSection> createState() => _StrengthSectionState();
}

class _StrengthSectionState extends ConsumerState<_StrengthSection> {
  int? _exerciseId;

  @override
  Widget build(BuildContext context) {
    final logged = ref.watch(loggedExercisesProvider).value;
    if (logged == null) return const SizedBox(height: 120);
    if (logged.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.show_chart_rounded,
        title: 'Charts need data',
        message: 'Finish a workout and your lifts show up here.',
      );
    }
    final selected = logged.firstWhere(
      (e) => e.id == _exerciseId,
      orElse: () => logged.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in logged.take(12))
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: SelectChip(
                    label: e.name,
                    color: e.primaryMuscle.color,
                    selected: e.id == selected.id,
                    onTap: () => setState(() => _exerciseId = e.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ExerciseProgressCard(exercise: selected, unit: widget.unit),
      ],
    );
  }
}

/// Best-per-workout chart for one exercise. Also used on its details page.
class ExerciseProgressCard extends ConsumerWidget {
  const ExerciseProgressCard({
    super.key,
    required this.exercise,
    required this.unit,
    this.linkToDetails = true,
  });
  final Exercise exercise;
  final WeightUnit unit;
  final bool linkToDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = metricFor(exercise.trackingType);
    final raw =
        ref
            .watch(
              exerciseProgressProvider((
                exerciseId: exercise.id,
                metric: metric,
              )),
            )
            .value ??
        const <ChartPoint>[];
    final isWeight =
        metric == ProgressMetric.e1rm || metric == ProgressMetric.topWeight;
    final points = [
      for (final p in raw) (x: p.x, y: isWeight ? kgToDisplay(p.y, unit) : p.y),
    ];
    final suffix = isWeight ? unitLabel(unit) : metric.unit;
    String fmt(double v) =>
        '${formatNumber(double.parse(v.toStringAsFixed(1)))} $suffix';
    final text = Theme.of(context).textTheme;
    final color = exercise.primaryMuscle.color;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: linkToDetails
          ? () => context.push(Routes.exerciseDetails(exercise.id))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: text.titleSmall),
                    Text(
                      metric.label,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (points.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('BEST', style: AppText.overline),
                    Text(
                      fmt(
                        points.map((p) => p.y).reduce((a, b) => a > b ? a : b),
                      ),
                      style: AppText.metricM.copyWith(fontSize: 18),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (points.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                points.isEmpty
                    ? 'No sets logged yet.'
                    : 'One session so far: ${fmt(points.first.y)}. Log it again to see a trend.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            TimeLineChart(
              points: points,
              color: color,
              formatValue: fmt,
              height: 170,
              semanticsLabel:
                  '${exercise.name} ${metric.label}, ${points.length} '
                  'sessions, best ${fmt(points.map((p) => p.y).reduce((a, b) => a > b ? a : b))}',
            ),
        ],
      ),
    );
  }
}
