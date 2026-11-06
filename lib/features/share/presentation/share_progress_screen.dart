import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/day_card.dart';
import '../data/share_stats.dart';
import 'story_cards.dart';

enum _Template { day, week, workout }

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
  _Template _template = _Template.day;
  bool _sharing = false;

  /// Optional background photo for the Day card (e.g. a pump pic).
  Uint8List? _photo;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1440,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      // Decode before showing so the shared image never misses the photo.
      await precacheImage(MemoryImage(bytes), context);
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t open that photo.')),
        );
      }
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / storySize.width);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = switch (_template) {
        _Template.day => 'lock-in-day.png',
        _Template.week => 'lock-in-week.png',
        _Template.workout => 'lock-in-workout.png',
      };
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
    final day = ref.watch(dayCardProvider);

    Widget? card;
    var hasData = true;
    if (_template == _Template.day) {
      final d = day.value;
      if (d != null) card = DayStoryCard(data: d, photo: _photo);
    } else if (_template == _Template.week) {
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
                  label: 'Today',
                  selected: _template == _Template.day,
                  onTap: () => setState(() => _template = _Template.day),
                ),
                const SizedBox(width: AppSpacing.sm),
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
          if (_template == _Template.day) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: _photo == null ? 'Add photo' : 'Change',
                      icon: Icons.photo_library_rounded,
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Camera',
                      icon: Icons.photo_camera_rounded,
                      onPressed: () => _pickPhoto(ImageSource.camera),
                    ),
                  ),
                  if (_photo != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      tooltip: 'Remove photo',
                      onPressed: () => setState(() => _photo = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
