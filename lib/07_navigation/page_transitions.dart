import 'package:flutter/material.dart';

/// A calm fade-through route transition: the old page fades out early, the
/// new one fades in while scaling up from 96%.
///
/// Source: Cookly `core/motion/page_transitions.dart`. Use it through
/// [fadeThroughTransitions] in `ThemeData.pageTransitionsTheme` (or pass it
/// to `AppTheme.build`) so every `MaterialPageRoute` uses it.
///
/// ```dart
/// AppTheme.build(palette, Brightness.light, pageTransitionsTheme: fadeThroughTransitions)
/// ```
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Incoming: wait, then fade in over the back part of the transition so
    // the two pages are never both fully opaque.
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
    );
    final scaleIn = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    // Outgoing: fade out early.
    final fadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0, 0.35, curve: Curves.easeIn),
      ),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: FadeTransition(
        opacity: fadeIn,
        child: ScaleTransition(scale: scaleIn, child: child),
      ),
    );
  }
}

/// Fade-through on every platform.
const fadeThroughTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
    TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
    TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeThroughPageTransitionsBuilder(),
  },
);

/// Dismisses the keyboard whenever a route is pushed or popped.
///
/// Source: Cookly `app/app.dart`. Flutter restores focus to a route's last
/// focused field when it becomes current again, so coming back from a
/// detail page re-opened the search keyboard by itself.
///
/// ```dart
/// MaterialApp(navigatorObservers: [UnfocusOnNavigate()])
/// ```
class UnfocusOnNavigate extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _unfocus();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _unfocus();

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus(
    disposition: UnfocusDisposition.scope,
  );
}
