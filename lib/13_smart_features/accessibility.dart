/// Accessibility helpers: WCAG contrast checks, an in-app accessibility
/// settings scope (text size, bold text, reduce motion, high contrast),
/// screen-reader announcements and a minimum-size tap target.
///
/// **Not AI.** Contrast uses the WCAG 2.x relative-luminance formula; the
/// scope only overrides `MediaQuery`/`Theme` values that Flutter widgets
/// (and every component in this toolkit) already respect.
///
/// Suits: every app — and judges notice. Especially apps for older users,
/// low-vision users, health, education and public services.
///
/// ```dart
/// // In MaterialApp.builder, so it covers every route:
/// MaterialApp(
///   builder: (context, child) => AccessibilityScope(
///     preferences: ref.watch(a11yPrefsProvider),   // from your settings screen
///     child: child!,
///   ),
/// );
///
/// meetsWcag(Colors.grey, Colors.white);           // false — about 2.7:1, below 4.5:1
/// announce(context, '3 results found');           // read out by TalkBack/VoiceOver
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// WCAG relative luminance of [color], 0 (black) … 1 (white).
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio between two opaque colours, 1 … 21.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

enum WcagLevel { aa, aaa }

/// Whether [foreground] text on [background] passes WCAG. "Large" text is
/// ≥ 18pt regular or ≥ 14pt bold (about 24 / 18.7 logical pixels).
bool meetsWcag(
  Color foreground,
  Color background, {
  bool largeText = false,
  WcagLevel level = WcagLevel.aa,
}) {
  final needed = switch ((level, largeText)) {
    (WcagLevel.aa, false) => 4.5,
    (WcagLevel.aa, true) => 3.0,
    (WcagLevel.aaa, false) => 7.0,
    (WcagLevel.aaa, true) => 4.5,
  };
  return contrastRatio(foreground, background) >= needed;
}

/// Black or white, whichever reads better on [background] — for text on
/// user-chosen colours (tags, categories, avatars).
Color readableOn(Color background) =>
    contrastRatio(Colors.black, background) >=
        contrastRatio(Colors.white, background)
    ? Colors.black
    : Colors.white;

/// In-app accessibility settings, on top of the device's own.
@immutable
class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.textScale = 1,
    this.boldText = false,
    this.reduceMotion = false,
    this.highContrast = false,
  });

  /// Multiplies the system text size; clamped to 0.8 … 2.5.
  final double textScale;
  final bool boldText;
  final bool reduceMotion;
  final bool highContrast;

  AccessibilityPreferences copyWith({
    double? textScale,
    bool? boldText,
    bool? reduceMotion,
    bool? highContrast,
  }) => AccessibilityPreferences(
    textScale: textScale ?? this.textScale,
    boldText: boldText ?? this.boldText,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    highContrast: highContrast ?? this.highContrast,
  );

  Map<String, dynamic> toJson() => {
    'textScale': textScale,
    'boldText': boldText,
    'reduceMotion': reduceMotion,
    'highContrast': highContrast,
  };

  factory AccessibilityPreferences.fromJson(Map<String, dynamic> json) =>
      AccessibilityPreferences(
        textScale: (json['textScale'] as num?)?.toDouble() ?? 1,
        boldText: json['boldText'] == true,
        reduceMotion: json['reduceMotion'] == true,
        highContrast: json['highContrast'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is AccessibilityPreferences &&
      other.textScale == textScale &&
      other.boldText == boldText &&
      other.reduceMotion == reduceMotion &&
      other.highContrast == highContrast;

  @override
  int get hashCode =>
      Object.hash(textScale, boldText, reduceMotion, highContrast);
}

/// Applies [preferences] below it. Device settings still win when they are
/// stronger (system "remove animations" stays on even if the app toggle is
/// off). High contrast regenerates the colour scheme from the current
/// primary colour at maximum contrast.
class AccessibilityScope extends StatelessWidget {
  const AccessibilityScope({
    super.key,
    required this.preferences,
    required this.child,
  });

  final AccessibilityPreferences preferences;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final systemScale = media.textScaler.scale(1);
    Widget result = MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(
          systemScale * preferences.textScale.clamp(0.8, 2.5),
        ),
        boldText: media.boldText || preferences.boldText,
        disableAnimations: media.disableAnimations || preferences.reduceMotion,
        highContrast: media.highContrast || preferences.highContrast,
      ),
      child: child,
    );
    if (preferences.highContrast) {
      final theme = Theme.of(context);
      result = Theme(
        data: theme.copyWith(
          colorScheme: highContrastScheme(theme.colorScheme),
        ),
        child: result,
      );
    }
    return result;
  }
}

/// [scheme] regenerated from its primary colour at maximum contrast.
ColorScheme highContrastScheme(ColorScheme scheme) => ColorScheme.fromSeed(
  seedColor: scheme.primary,
  brightness: scheme.brightness,
  contrastLevel: 1,
);

/// Asks the screen reader to read [message] now — for changes that are not
/// focused, like "Saved", "3 results" or "Timer finished".
Future<void> announce(
  BuildContext context,
  String message, {
  bool assertive = false,
}) => SemanticsService.sendAnnouncement(
  View.of(context),
  message,
  Directionality.of(context),
  assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
);

/// Gives a small visual (an icon, a dot, a 24px avatar) a 48×48 tap area
/// and a spoken label, as Android and iOS guidelines require.
class AccessibleTapTarget extends StatelessWidget {
  const AccessibleTapTarget({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.minSize = kMinInteractiveDimension,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final double minSize;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: minSize / 2,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    ),
  );
}
