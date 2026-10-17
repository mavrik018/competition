/// Layout that adapts to the window, using Material 3's window size
/// classes: compact (< 600), medium (600–839), expanded (≥ 840).
///
/// Newly written to complement `MaxWidthFrame`. StudyBuddies only knew
/// "phone vs tablet"; size classes based on the *available width* also
/// handle split-screen, foldables, desktop windows and the web.
///
/// ```dart
/// ResponsiveBuilder(
///   compact: (_) => SingleColumn(),
///   expanded: (_) => TwoColumns(),       // medium falls back to compact
/// )
///
/// ResponsiveGrid(minItemWidth: 160, children: [for (final s in stats) StatCard(...)])
/// ```
library;

import 'package:flutter/widgets.dart';

import '../01_design_system/app_tokens.dart';

enum WindowSize { compact, medium, expanded }

/// The size class for a [width] in logical pixels.
WindowSize windowSizeFor(double width) => width >= 840
    ? WindowSize.expanded
    : (width >= 600 ? WindowSize.medium : WindowSize.compact);

/// Builds a different layout per size class, measured from the space the
/// widget actually has (not the whole screen). Missing builders fall back
/// to the next smaller one.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          switch (windowSizeFor(constraints.maxWidth)) {
            WindowSize.expanded => (expanded ?? medium ?? compact)(context),
            WindowSize.medium => (medium ?? compact)(context),
            WindowSize.compact => compact(context),
          },
    );
  }
}

/// How many columns of at least [minItemWidth] fit in [width] with
/// [spacing] between them. Never fewer than 1 or more than [maxColumns].
int gridColumnsFor(
  double width, {
  required double minItemWidth,
  double spacing = Gap.md,
  int maxColumns = 6,
}) {
  if (width <= 0) return 1;
  final columns = ((width + spacing) / (minItemWidth + spacing)).floor();
  return columns.clamp(1, maxColumns);
}

/// A non-scrolling grid whose column count follows the available width.
/// Items in a row share its height (tallest wins), so cards line up.
/// Put it inside a scroll view; for long lists use `GridView.builder`.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 160,
    this.spacing = Gap.md,
    this.maxColumns = 6,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = gridColumnsFor(
          constraints.maxWidth,
          minItemWidth: minItemWidth,
          spacing: spacing,
          maxColumns: maxColumns,
        );
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final rowItems = children.sublist(
            start,
            (start + columns).clamp(0, children.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing,
                children: [
                  for (final item in rowItems) Expanded(child: item),
                  // Keep the last row's items the same width as the others.
                  for (var i = rowItems.length; i < columns; i++)
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: rows,
        );
      },
    );
  }
}
