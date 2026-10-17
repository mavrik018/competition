import 'package:competition_toolkit/01_design_system/app_palette.dart';
import 'package:competition_toolkit/01_design_system/app_theme.dart';
import 'package:flutter/material.dart';

/// Wraps [child] in a themed MaterialApp + Scaffold, the way every widget
/// test needs it.
Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: AppTheme.build(AppPalette.studyBlue, brightness),
    home: Scaffold(body: child),
  );
}

/// A MaterialApp whose home is a button that runs [onPressed] with a
/// context under the Navigator — for testing dialogs and sheets.
Widget launcher(void Function(BuildContext context) onPressed) {
  return MaterialApp(
    theme: AppTheme.build(AppPalette.studyBlue, Brightness.light),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => onPressed(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}
