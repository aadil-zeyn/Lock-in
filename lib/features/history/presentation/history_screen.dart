import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/widgets.dart';
import '../data/history_providers.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Every completed workout, grouped by month, searchable by name.
/// Opened from the Workout tab.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(workoutHistoryProvider).value;
    final q = _query.trim().toLowerCase();
    final items = all == null
        ? null
        : [
            for (final i in all)
              if (q.isEmpty || i.workout.name.toLowerCase().contains(q)) i,
          ];

    final children = <Widget>[];
    if (items != null) {
      String? month;
      for (final item in items) {
        final d = item.workout.startedAt;
        final m = '${_monthNames[d.month - 1]} ${d.year}';
        if (m != month) {
          month = m;
          final count = items
              .where(
                (x) =>
                    x.workout.startedAt.month == d.month &&
                    x.workout.startedAt.year == d.year,
              )
              .length;
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.lg,
                0,
                AppSpacing.sm,
              ),
              child: Text(
                '${m.toUpperCase()} · $count',
                style: AppText.overline,
              ),
            ),
          );
        }
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: WorkoutHistoryTile(item: item),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              0,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search workouts',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? EmptyState(
                    icon: Icons.history_rounded,
                    title: q.isEmpty ? 'Nothing logged yet' : 'No matches',
                    message: q.isEmpty
                        ? 'Finished workouts appear here, newest first.'
                        : 'Try another name.',
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: children,
                  ),
          ),
        ],
      ),
    );
  }
}

/// One finished workout: date badge, name, exercises · sets · time.
class WorkoutHistoryTile extends StatelessWidget {
  const WorkoutHistoryTile({super.key, required this.item});
  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final w = item.workout;
    final text = Theme.of(context).textTheme;
    final mins = (w.durationSeconds ?? 0) ~/ 60;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: () => context.push(Routes.workoutSummary(w.id)),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.workouts.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${w.startedAt.day}',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.workouts,
                  ),
                ),
                Text(
                  formatShortDate(w.startedAt).split(' ').last.toUpperCase(),
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.workouts,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${item.exercises} exercise${item.exercises == 1 ? '' : 's'}'
                  ' · ${item.sets} sets'
                  '${mins > 0 ? ' · ${formatDuration(Duration(minutes: mins))}' : ''}',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
