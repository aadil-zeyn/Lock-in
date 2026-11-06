import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_card.dart';

/// Big number + unit + label. The core "data-focused" building block.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final IconData? icon;
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
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Expanded(
                child: Text(label.toUpperCase(),
                    style: AppText.overline, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: AppText.metricL),
              if (unit != null) TextSpan(text: ' $unit', style: AppText.unit),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
