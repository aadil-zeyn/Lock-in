import 'package:flutter/material.dart';

/// Lock-in colour palette. Pure-black, fitness-band style: neutral surfaces,
/// one brand accent for primary actions, and a fixed colour per metric so a
/// number is recognisable at a glance (workouts are always orange, etc.).
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF131316);
  static const surfaceHigh = Color(0xFF1F1F24);
  static const outline = Color(0xFF2C2C33);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9A9AA1);
  static const textTertiary = Color(0xFF63636B);

  /// Brand colour: primary buttons, selected tab, focus rings.
  static const accent = Color(0xFFFF7A1A);
  static const onAccent = Color(0xFF0A0A0B);

  // Metric colours — always pair them with an icon or label, never colour alone.
  static const workouts = accent;
  static const time = Color(0xFFA57CFF);
  static const sets = Color(0xFF2ED47A);
  static const volume = Color(0xFF3D9BFF);
  static const body = Color(0xFF22D3EE);
  static const records = Color(0xFFFFC53D);
  static const streak = Color(0xFFFF4D6D);

  // Muscle regions (see `muscle_style.dart`).
  static const push = accent;
  static const pull = volume;
  static const legs = sets;
  static const core = time;

  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFFF5A5F);
}

abstract final class AppGradients {
  /// Hero "start workout" card.
  static const energy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A1A), Color(0xFFFF4D6D)],
  );

  /// Subtle tint for a card themed by [color].
  static LinearGradient tint(Color color) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.04)],
  );
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
  static const page = 16.0;
}

abstract final class AppRadius {
  static const card = 24.0;
  static const tile = 20.0;
  static const button = 18.0;
  static const chip = 14.0;
}

/// Text styles that sit outside the Material text theme —
/// mostly big numbers. Tabular figures stop digits shifting width.
abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  static const metricXL = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1.0,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const metricL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.05,
    color: AppColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const metricM = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
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
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );
}
