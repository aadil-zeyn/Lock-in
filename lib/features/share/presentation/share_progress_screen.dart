import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/share_stats.dart';
import 'story_cards.dart';

enum _Template { week, workout }

/// Preview a 9:16 story card and share it as a 1080 × 1920 PNG
/// (Instagram Stories, WhatsApp status…). It's also screenshot-ready.
class ShareProgressScreen extends ConsumerStatefulWidget {
  const ShareProgressScreen({super.key});

  @override
  ConsumerState<ShareProgressScreen> createState() =>
      _ShareProgressScreenState();
}

class _ShareProgressScreenState extends ConsumerState<ShareProgressScreen> {
  final _cardKey = GlobalKey();
  _Template _template = _Template.week;
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / storySize.width);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = _template == _Template.week
          ? 'lock-in-week.png'
          : 'lock-in-workout.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes!.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: [name],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn\'t share the image. Take a screenshot instead.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final unit = profile?.weightUnit ?? WeightUnit.kg;
    final week = ref.watch(weekShareProvider);
    final last = ref.watch(lastWorkoutShareProvider);

    Widget? card;
    var hasData = true;
    if (_template == _Template.week) {
      final d = week.value;
      if (d != null) {
        card = WeekStoryCard(
          data: d,
          unit: unit,
          workoutGoal: profile?.weeklyWorkoutGoal ?? 3,
          minutesGoal: profile?.weeklyMinutesGoal ?? 180,
          setsGoal: profile?.weeklySetsGoal ?? 45,
        );
      }
    } else {
      final d = last.value;
      if (d != null) {
        card = WorkoutStoryCard(detail: d, unit: unit);
      } else if (!last.isLoading) {
        hasData = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Share progress')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: PrimaryButton(
          label: _sharing ? 'Preparing…' : 'Share to Instagram & more',
          icon: Icons.ios_share_rounded,
          onPressed: card == null || _sharing ? null : _share,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                SelectChip(
                  label: 'This week',
                  selected: _template == _Template.week,
                  onTap: () => setState(() => _template = _Template.week),
                ),
                const SizedBox(width: AppSpacing.sm),
                SelectChip(
                  label: 'Last workout',
                  selected: _template == _Template.workout,
                  onTap: () => setState(() => _template = _Template.workout),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: !hasData
                ? const EmptyState(
                    icon: Icons.fitness_center_rounded,
                    title: 'No workouts yet',
                    message: 'Finish one and you can share it here.',
                  )
                : card == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: Center(
                      child: FittedBox(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: RepaintBoundary(key: _cardKey, child: card),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              0,
            ),
            child: Text(
              'Shares a 1080 × 1920 image — pick Instagram, then Stories.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
