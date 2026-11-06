import 'package:flutter/material.dart';

/// Lock-in colour palette. Dark-first, one accent ("volt").
abstract final class AppColors {
  static const background = Color(0xFF0A0A0B);
  static const surface = Color(0xFF141416);
  static const surfaceHigh = Color(0xFF1C1C1F);
  static const outline = Color(0xFF2A2A2E);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9A9AA1);
  static const textTertiary = Color(0xFF63636B);

  static const accent = Color(0xFFC8FF2E);
  static const onAccent = Color(0xFF0A0A0B);

  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFFF5A5F);
}

/// 4-pt spacing scale.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal page gutter.
  static const page = 20.0;
}

abstract final class AppRadius {
  static const card = 20.0;
  static const button = 16.0;
  static const chip = 12.0;
}

/// Text styles that sit outside the Material text theme —
/// mostly big numbers. Tabular figures stop digits shifting width.
abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  static const metricXL = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    height: 1.0,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const metricL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.05,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const metricM = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const unit = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Small uppercase label above a metric.
  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );
}
