import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Pill-shaped toggle. Selected = filled with [color] plus a tick, so the
/// state never relies on colour alone.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.accent,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.onAccent
        : (enabled ? AppColors.textPrimary : AppColors.textTertiary);
    final leading = selected ? Icons.check_rounded : icon;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? color : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Icon(
                    leading,
                    size: 16,
                    color: selected || !enabled ? fg : color,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
