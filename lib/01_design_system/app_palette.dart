import 'package:flutter/material.dart';

/// A brand palette that produces a matching light and dark [ColorScheme],
/// plus the status colours Material does not define.
///
/// Source: StudyBuddies `app_colors.dart` (light/dark `context` getters),
/// Cookly `app_colors.dart` (hand-written M3 scheme), Couple `app_theme.dart`
/// (seeded scheme). The three were merged into one idea: describe a brand
/// with a few seed colours and let [ColorScheme.fromSeed] derive the
/// accessible tonal roles, instead of hand-maintaining ~40 hex values per mode.
@immutable
class AppPalette {
  const AppPalette({
    required this.primary,
    this.secondary,
    this.tertiary,
    this.error,
    this.success = const Color(0xFF2E7D32),
    this.warning = const Color(0xFFB26A00),
    this.info = const Color(0xFF1565C0),
  });

  /// The brand colour. Used verbatim as `primary` in light mode; dark mode
  /// uses the seeded tone instead so it keeps contrast on dark surfaces.
  final Color primary;
  final Color? secondary;
  final Color? tertiary;
  final Color? error;
  final Color success;
  final Color warning;
  final Color info;

  ColorScheme scheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: isLight ? primary : null,
      secondary: isLight ? secondary : null,
      tertiary: isLight ? tertiary : null,
      error: isLight ? error : null,
    );
  }

  SemanticColors semantic(Brightness brightness) =>
      brightness == Brightness.light
      ? SemanticColors(success: success, warning: warning, info: info)
      : SemanticColors(
          // Lighter tones read better on dark surfaces.
          success: Color.lerp(success, Colors.white, 0.35)!,
          warning: Color.lerp(warning, Colors.white, 0.35)!,
          info: Color.lerp(info, Colors.white, 0.35)!,
        );

  // ── Presets taken from the source apps ────────────────────────────────────

  /// StudyBuddies: dark blue with a bright blue accent.
  static const studyBlue = AppPalette(
    primary: Color(0xFF1E3A8A),
    secondary: Color(0xFF4A6CF7),
    tertiary: Color(0xFF4B5563),
    error: Color(0xFFEF4444),
  );

  /// Cookly: burnt orange, earthy teal and mustard.
  static const kitchenWarm = AppPalette(
    primary: Color(0xFFA63517),
    secondary: Color(0xFF376847),
    tertiary: Color(0xFF7B5500),
    error: Color(0xFFBA1A1A),
  );

  /// Couple: deep navy with terracotta.
  static const coupleNavy = AppPalette(
    primary: Color(0xFF28273F),
    secondary: Color(0xFFD37962),
  );

  /// TaskFlow: vibrant indigo.
  static const taskIndigo = AppPalette(
    primary: Color(0xFF6366F1),
    error: Color(0xFFE11D48),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
  );
}

/// Status colours as a [ThemeExtension], so widgets can read
/// `SemanticColors.of(context).success` the same way they read `ColorScheme`.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color success;
  final Color warning;
  final Color info;

  /// Falls back to sensible defaults when the theme was not built with
  /// `AppTheme.build`, so components never crash on a plain `ThemeData`.
  static SemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<SemanticColors>() ??
        const AppPalette(primary: Colors.blue).semantic(theme.brightness);
  }

  @override
  SemanticColors copyWith({Color? success, Color? warning, Color? info}) =>
      SemanticColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
      );

  @override
  SemanticColors lerp(SemanticColors? other, double t) {
    if (other == null) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
