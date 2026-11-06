import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_card.dart';

/// Friendly placeholder shown when there is no data yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Compact = inside a card on a busy screen; otherwise full-page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 48 : 72,
          height: compact ? 48 : 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(compact ? 16 : 24),
          ),
          child: Icon(icon,
              size: compact ? 24 : 34, color: AppColors.textSecondary),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text(title,
            textAlign: TextAlign.center,
            style: compact ? text.titleMedium : text.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.lg),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    if (compact) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
        child: Center(child: content),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xxl * 2),
      child: Center(child: content),
    );
  }
}
