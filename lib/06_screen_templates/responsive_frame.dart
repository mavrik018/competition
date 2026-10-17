/// Keeps phone-designed layouts readable on tablets and desktop: content is
/// centred in a column of at most [MaxWidthFrame.maxWidth] instead of
/// stretching across a 13-inch screen.
///
/// Source: StudyBuddies `tablet_frame.dart` (`TabletFrame`, `AdaptiveSliver`)
/// and `responsive.dart` (`context.isTablet`, `adaptiveCrossAxisCount`). The
/// source was entangled with `flutter_screenutil` (it re-configured the
/// scale factor for tablets); without screenutil, a max-width constraint is
/// all that is needed.
///
/// ```dart
/// Scaffold(body: MaxWidthFrame(child: SettingsList()))
///
/// GridView.count(
///   crossAxisCount: adaptiveColumnCount(MediaQuery.sizeOf(context).width),
///   children: cards,
/// )
/// ```
library;

import 'package:flutter/widgets.dart';

/// Devices whose shortest side is at least this are treated as tablets.
/// Shortest side (not width) keeps a phone in landscape a phone.
const double kTabletBreakpoint = 600;

extension ResponsiveContext on BuildContext {
  bool get isTablet =>
      MediaQuery.sizeOf(this).shortestSide >= kTabletBreakpoint;

  /// [tablet] on tablets, [phone] otherwise.
  T responsive<T>({required T phone, required T tablet}) =>
      isTablet ? tablet : phone;
}

/// Centres [child] and caps its width. A pass-through when the screen is
/// narrower than [maxWidth].
class MaxWidthFrame extends StatelessWidget {
  const MaxWidthFrame({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    // heightFactor: 1 keeps the frame exactly as tall as its child. Without
    // it, under loose-but-bounded height (e.g. a Scaffold's
    // bottomNavigationBar slot) Align expands to the full height — the bug
    // StudyBuddies documented in TabletFrame.
    return Align(
      alignment: alignment,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The sliver version of [MaxWidthFrame], for `CustomScrollView`s: pads the
/// sliver horizontally so its content stays within [maxWidth].
class MaxWidthSliver extends StatelessWidget {
  const MaxWidthSliver({super.key, required this.sliver, this.maxWidth = 640});

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = (width - maxWidth) / 2;
    if (side <= 0) return sliver;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      sliver: sliver,
    );
  }
}

/// How many grid columns fit [availableWidth] when no cell may be narrower
/// than [minCellWidth]. Never fewer than [min] or more than [max].
int adaptiveColumnCount(
  double availableWidth, {
  double minCellWidth = 180,
  int min = 2,
  int max = 4,
}) {
  if (availableWidth <= 0 || minCellWidth <= 0) return min;
  return (availableWidth / minCellWidth).floor().clamp(min, max);
}
