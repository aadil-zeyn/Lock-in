import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_card.dart';
import 'icon_badge.dart';

/// Band-style metric tile: coloured icon bubble, label, big number + unit.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.icon,
    this.color = AppColors.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final IconData? icon;

  /// Metric colour (see [AppColors]); tints the icon bubble.
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                IconBadge(icon: icon, color: color, size: 32),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: AppText.metricL),
                if (unit != null) TextSpan(text: ' $unit', style: AppText.unit),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
