import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// A tinted circle (or rounded square) holding an icon or short text.
/// The coloured "bubble" used throughout the band-style UI.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    this.icon,
    this.text,
    this.color = AppColors.accent,
    this.size = 40,
    this.circle = true,
  }) : assert(icon != null || text != null);

  final IconData? icon;
  final String? text;
  final Color color;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.32),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: color)
          : Text(
              text!,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: size * 0.3,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
    );
  }
}
