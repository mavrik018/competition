import 'package:flutter/material.dart';

/// The type ramp, mapped onto Material's [TextTheme] slots.
///
/// Source: StudyBuddies `app_typography.dart`. Its rule is kept: every size
/// is a step on Apple's Human Interface Guidelines scale (Large Title 34,
/// Title 1 28, Title 2 22, Title 3 20, Headline/Body 17, Callout 16,
/// Subheadline 15, Footnote 13, Caption 2 11), so text sits at the size the
/// platform itself uses for that role. Pick the slot whose size you want
/// instead of `copyWith(fontSize: …)` — ad-hoc overrides were what made the
/// same element render at different sizes on different screens in the source.
///
/// Changed in extraction: the source loaded Inter through `google_fonts` and
/// scaled through `flutter_screenutil`. Here the family is a parameter (null =
/// platform default, or any family declared in the app's pubspec) and sizes
/// are logical pixels, which already honour the user's text-scale setting.
abstract final class AppTypography {
  static TextTheme textTheme({required Color color, String? fontFamily}) {
    TextStyle style(
      double size,
      FontWeight weight,
      double height, [
      double letterSpacing = 0,
    ]) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );

    return TextTheme(
      // Hero numerals: a countdown, a score.
      displayLarge: style(46, FontWeight.w700, 1.1, -0.5),
      displayMedium: style(34, FontWeight.w700, 1.15, -0.5),
      displaySmall: style(28, FontWeight.w700, 1.2, -0.3),
      // Onboarding and empty-state headlines.
      headlineLarge: style(28, FontWeight.w700, 1.25, -0.3),
      headlineMedium: style(22, FontWeight.w700, 1.25, -0.3),
      headlineSmall: style(20, FontWeight.w600, 1.3, -0.2),
      // Structural headings. titleMedium (17) is the app-bar / sheet title.
      titleLarge: style(20, FontWeight.w600, 1.3, -0.2),
      titleMedium: style(17, FontWeight.w600, 1.3, -0.2),
      titleSmall: style(15, FontWeight.w600, 1.35),
      // Reading text. Emphasis is weight, not size.
      bodyLarge: style(17, FontWeight.w400, 1.5),
      bodyMedium: style(15, FontWeight.w400, 1.45),
      bodySmall: style(13, FontWeight.w400, 1.4),
      // Buttons, chips, captions. labelSmall (11) is the floor — badges only.
      labelLarge: style(16, FontWeight.w600, 1.3),
      labelMedium: style(13, FontWeight.w500, 1.4, 0.3),
      labelSmall: style(11, FontWeight.w500, 1.3, 0.5),
    );
  }

  /// Same style with fixed-width digits, so a ticking timer does not jitter.
  ///
  /// The source asked for a monospace family (`Roboto Mono`) that was never
  /// declared, so it silently fell back to a proportional face. Tabular
  /// figures fix the jitter in any font without loading another one.
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
