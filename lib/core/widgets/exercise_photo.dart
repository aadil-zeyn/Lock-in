import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// An exercise photo that alternates between its start and end frames,
/// like a slow GIF, with a "Start" / "End" label so the position isn't
/// shown by the picture alone. With reduce-motion on it stays still and a
/// tap flips the frame. The bundled photos have their own backgrounds, so
/// they sit in a rounded black-backed frame.
class ExercisePhoto extends StatefulWidget {
  const ExercisePhoto({
    super.key,
    required this.start,
    required this.end,
    required this.label,
    this.aspectRatio = 3 / 2,
    this.interval = const Duration(milliseconds: 1400),
  });

  final String start;
  final String end;

  /// Exercise name, for the screen-reader description.
  final String label;
  final double aspectRatio;
  final Duration interval;

  @override
  State<ExercisePhoto> createState() => _ExercisePhotoState();
}

class _ExercisePhotoState extends State<ExercisePhoto> {
  Timer? _timer;
  bool _end = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload both frames so the swap never flashes.
    precacheImage(AssetImage(widget.start), context);
    precacheImage(AssetImage(widget.end), context);
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(widget.interval, (_) {
        if (mounted) setState(() => _end = !_end);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _end ? widget.end : widget.start;
    return Semantics(
      image: true,
      label: 'Photo of ${widget.label}, start and end position',
      child: GestureDetector(
        onTap: () => setState(() => _end = !_end),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Image.asset(
                    frame,
                    key: ValueKey(frame),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: _FrameLabel(end: _end),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FrameLabel extends StatelessWidget {
  const _FrameLabel({required this.end});
  final bool end;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              end ? Icons.flag_rounded : Icons.play_arrow_rounded,
              size: 14,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              end ? 'End' : 'Start',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small square thumbnail (the start frame) for list tiles.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({
    super.key,
    required this.asset,
    required this.borderColor,
    this.size = 48,
  });
  final String asset;
  final Color borderColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: borderColor,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.chip - 1.5),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          cacheWidth: px * 2,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
