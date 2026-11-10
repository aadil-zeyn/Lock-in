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
import '../../food/data/food_repository.dart';
import '../data/day_card.dart';
import '../data/food_share.dart';
import '../data/share_stats.dart';
import 'share_backgrounds.dart';
import 'story_cards.dart';
import 'today_designs.dart';

/// Which story card the share screen shows.
enum ShareTemplate {
  day('Today'),
  week('This week'),
  workout('Last workout'),
  food('Food');

  const ShareTemplate(this.label);
  final String label;
}

/// Preview a 9:16 story card and share it as a 1080 × 1920 PNG
/// (Instagram Stories, WhatsApp status…). It's also screenshot-ready.
class ShareProgressScreen extends ConsumerStatefulWidget {
  const ShareProgressScreen({
    super.key,
    this.initial = ShareTemplate.day,
    this.foodDay,
  });

  final ShareTemplate initial;

  /// Day for the food card (the day open on the Food tab); null = today.
  final DateTime? foodDay;

  @override
  ConsumerState<ShareProgressScreen> createState() =>
      _ShareProgressScreenState();
}

class _ShareProgressScreenState extends ConsumerState<ShareProgressScreen> {
  final _cardKey = GlobalKey();
  late ShareTemplate _template = widget.initial;
  late final DateTime _foodDay = dayStart(widget.foodDay ?? DateTime.now());
  bool _sharing = false;

  /// "Today" layout, by [TodayDesign.id].
  String _designId = todayDesigns.first.id;

  /// "Today" background: null = today's suggested photo, [_none], [_own]
  /// (the user's photo), or a [ShareBackground.id].
  String? _bgChoice;
  static const _none = 'none';
  static const _own = 'own';

  /// The user's own photo (e.g. a pump pic).
  Uint8List? _photo;

  TodayDesign get _design => todayDesigns.firstWhere(
    (t) => t.id == _designId,
    orElse: () => todayDesigns.first,
  );

  String _bgKey(DayCardData d) =>
      _bgChoice ??
      suggestedBackground(workoutDay: !d.isRestDay, dayOfYear: d.day).id;

  ImageProvider? _bgImage(DayCardData d) {
    final key = _bgKey(d);
    if (key == _none) return null;
    if (key == _own) return _photo == null ? null : MemoryImage(_photo!);
    return AssetImage('assets/share/$key.webp');
  }

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
      if (mounted) {
        setState(() {
          _photo = bytes;
          _bgChoice = _own;
        });
      }
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
      // Make sure the background photo is decoded before capturing.
      final day = ref.read(dayCardProvider).value;
      final bg = _template == ShareTemplate.day && day != null
          ? _bgImage(day)
          : null;
      if (bg != null) await precacheImage(bg, context);
      await WidgetsBinding.instance.endOfFrame;
      if (_cardKey.currentContext == null) return;
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / storySize.width);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final name = switch (_template) {
        ShareTemplate.day => 'lock-in-today.png',
        ShareTemplate.week => 'lock-in-week.png',
        ShareTemplate.workout => 'lock-in-workout.png',
        ShareTemplate.food => 'lock-in-food.png',
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
    if (_template == ShareTemplate.day) {
      final d = day.value;
      if (d != null) card = _design.builder(d, _bgImage(d));
    } else if (_template == ShareTemplate.food) {
      final d = ref.watch(foodShareProvider(_foodDay)).value;
      if (d != null) {
        if (d.isEmpty) {
          hasData = false;
        } else {
          card = FoodStoryCard(data: d);
        }
      }
    } else if (_template == ShareTemplate.week) {
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final t in ShareTemplate.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: SelectChip(
                      label: t.label,
                      selected: _template == t,
                      onTap: () => setState(() => _template = t),
                    ),
                  ),
              ],
            ),
          ),
          if (_template == ShareTemplate.day) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                children: [
                  for (final t in todayDesigns)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: SelectChip(
                        label: t.name,
                        selected: t.id == _design.id,
                        onTap: () => setState(() => _designId = t.id),
                      ),
                    ),
                ],
              ),
            ),
            if (day.value case final d?) ...[
              const SizedBox(height: AppSpacing.sm),
              _BackgroundStrip(
                selected: _bgKey(d),
                backgrounds: backgroundsFor(workoutDay: !d.isRestDay),
                photo: _photo,
                onSelect: (key) {
                  if (key != _none && key != _own) {
                    precacheImage(
                      AssetImage('assets/share/$key.webp'),
                      context,
                    );
                  }
                  setState(() => _bgChoice = key);
                },
                onGallery: () => _pickPhoto(ImageSource.gallery),
                onCamera: () => _pickPhoto(ImageSource.camera),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: !hasData
                ? _template == ShareTemplate.food
                      ? EmptyState(
                          icon: Icons.restaurant_rounded,
                          title: _foodDay == dayStart(DateTime.now())
                              ? 'Nothing logged today'
                              : 'Nothing logged that day',
                          message: 'Log a meal on the Food tab to share it.',
                        )
                      : const EmptyState(
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

/// Background picker: no photo, the user's own (gallery / camera), then
/// the bundled photos with the ones that suit today first.
class _BackgroundStrip extends StatelessWidget {
  const _BackgroundStrip({
    required this.selected,
    required this.backgrounds,
    required this.photo,
    required this.onSelect,
    required this.onGallery,
    required this.onCamera,
  });

  final String selected;
  final List<ShareBackground> backgrounds;
  final Uint8List? photo;
  final ValueChanged<String> onSelect;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final own = photo;
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        children: [
          _Thumb(
            label: 'No photo',
            selected: selected == _ShareProgressScreenState._none,
            onTap: () => onSelect(_ShareProgressScreenState._none),
            child: const ColoredBox(
              color: AppColors.surfaceHigh,
              child: Icon(
                Icons.block_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          _Thumb(
            label: 'Your photo from gallery',
            selected: false,
            onTap: onGallery,
            child: const ColoredBox(
              color: AppColors.surfaceHigh,
              child: Icon(
                Icons.add_photo_alternate_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          _Thumb(
            label: 'Take a photo',
            selected: false,
            onTap: onCamera,
            child: const ColoredBox(
              color: AppColors.surfaceHigh,
              child: Icon(
                Icons.photo_camera_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          if (own != null)
            _Thumb(
              label: 'Your photo',
              selected: selected == _ShareProgressScreenState._own,
              onTap: () => onSelect(_ShareProgressScreenState._own),
              child: Image.memory(own, fit: BoxFit.cover, cacheWidth: 120),
            ),
          for (final b in backgrounds)
            _Thumb(
              label: b.label,
              selected: selected == b.id,
              onTap: () => onSelect(b.id),
              child: Image.asset(b.asset, fit: BoxFit.cover, cacheWidth: 120),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    // A tick as well as the border: not colour alone.
                    if (selected)
                      const Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
