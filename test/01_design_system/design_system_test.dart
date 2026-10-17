import 'package:competition_toolkit/01_design_system/app_palette.dart';
import 'package:competition_toolkit/01_design_system/app_theme.dart';
import 'package:competition_toolkit/01_design_system/app_tokens.dart';
import 'package:competition_toolkit/01_design_system/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPalette', () {
    test('light scheme uses the brand colour verbatim', () {
      final scheme = AppPalette.kitchenWarm.scheme(Brightness.light);
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, AppPalette.kitchenWarm.primary);
      expect(scheme.secondary, AppPalette.kitchenWarm.secondary);
    });

    test('dark scheme derives its own primary for contrast', () {
      final scheme = AppPalette.studyBlue.scheme(Brightness.dark);
      expect(scheme.brightness, Brightness.dark);
      // The dark-blue brand colour would be unreadable on a dark surface.
      expect(scheme.primary, isNot(AppPalette.studyBlue.primary));
      expect(
        ThemeData.estimateBrightnessForColor(scheme.primary),
        Brightness.light,
      );
    });

    test('semantic colours are lightened in dark mode', () {
      final light = AppPalette.taskIndigo.semantic(Brightness.light);
      final dark = AppPalette.taskIndigo.semantic(Brightness.dark);
      expect(light.success, AppPalette.taskIndigo.success);
      expect(
        dark.success.computeLuminance(),
        greaterThan(light.success.computeLuminance()),
      );
    });
  });

  group('SemanticColors', () {
    test('lerp interpolates and copyWith replaces', () {
      const a = SemanticColors(
        success: Color(0xFF000000),
        warning: Color(0xFF000000),
        info: Color(0xFF000000),
      );
      const b = SemanticColors(
        success: Color(0xFFFFFFFF),
        warning: Color(0xFFFFFFFF),
        info: Color(0xFFFFFFFF),
      );
      expect(a.lerp(b, 1).success, b.success);
      expect(a.lerp(null, 0.5), same(a));
      expect(a.copyWith(info: b.info).info, b.info);
    });

    testWidgets('of() falls back when the theme has no extension', (
      tester,
    ) async {
      late SemanticColors colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          home: Builder(
            builder: (context) {
              colors = SemanticColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(colors.success, isNotNull);
    });
  });

  group('AppTheme.build', () {
    for (final brightness in Brightness.values) {
      test('produces a complete $brightness theme', () {
        final theme = AppTheme.build(AppPalette.coupleNavy, brightness);
        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.brightness, brightness);
        expect(theme.extension<SemanticColors>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
        expect(theme.textTheme.titleMedium!.fontSize, 17);
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      });
    }

    test('passes the font family and page transitions through', () {
      const transitions = PageTransitionsTheme();
      final theme = AppTheme.build(
        AppPalette.studyBlue,
        Brightness.light,
        fontFamily: 'Inter',
        pageTransitionsTheme: transitions,
      );
      expect(theme.textTheme.bodyLarge!.fontFamily, 'Inter');
      expect(theme.pageTransitionsTheme, same(transitions));
    });
  });

  group('AppTypography', () {
    test('follows the Apple HIG ramp', () {
      final text = AppTypography.textTheme(color: Colors.black);
      expect(text.displayMedium!.fontSize, 34); // Large Title
      expect(text.bodyLarge!.fontSize, 17); // Body
      expect(text.bodyMedium!.fontSize, 15); // Subheadline
      expect(text.labelSmall!.fontSize, 11); // Caption 2 — the floor
    });

    test('tabular adds fixed-width digits and keeps the rest', () {
      const base = TextStyle(fontSize: 20, color: Colors.red);
      final style = AppTypography.tabular(base);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.fontSize, 20);
      expect(style.color, Colors.red);
    });
  });

  test('tokens increase monotonically', () {
    const gaps = [Gap.xxs, Gap.xs, Gap.sm, Gap.md, Gap.lg, Gap.xl, Gap.xxl];
    for (var i = 1; i < gaps.length; i++) {
      expect(gaps[i], greaterThan(gaps[i - 1]));
    }
    expect(AppShadows.soft(Colors.blue).single.color.a, closeTo(0.06, 0.01));
  });
}
