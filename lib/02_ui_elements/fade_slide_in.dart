import 'dart:async';

import 'package:flutter/material.dart';

/// Entrance motion: content fades in while rising a few pixels, optionally
/// staggered by index so a list settles into place item by item.
///
/// Source: Cookly `core/motion/entrance.dart` (`fadeSlideIn`, `Stagger`),
/// which used the `flutter_animate` package. Rewritten with a plain
/// [AnimationController] so it has no dependency.
///
/// ```dart
/// Column(children: [
///   for (var i = 0; i < items.length; i++)
///     FadeSlideIn(index: i, child: ItemTile(items[i])),
/// ])
/// ```
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delayStep = const Duration(milliseconds: 55),
    this.duration = const Duration(milliseconds: 380),
    this.offset = 16,
  });

  final Widget child;

  /// Position in a list. Each step delays the start by [delayStep].
  final int index;
  final Duration delayStep;
  final Duration duration;

  /// How far below its resting place the child starts, in logical pixels.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final delay = widget.delayStep * widget.index;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS "reduce motion" setting: show the content immediately.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Lays out [children] in a column (or row) and staggers their entrance with
/// one shared cadence, so a whole section can be re-timed in one place.
class Stagger extends StatelessWidget {
  const Stagger({
    super.key,
    required this.children,
    this.delayStep = const Duration(milliseconds: 55),
    this.axis = Axis.vertical,
    this.spacing = 0,
    this.crossAxisAlignment,
  });

  final List<Widget> children;
  final Duration delayStep;
  final Axis axis;
  final double spacing;

  /// Defaults to stretch for a column and center for a row (stretching a row
  /// needs a bounded height, which a row in a scroll view does not have).
  final CrossAxisAlignment? crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: axis,
      crossAxisAlignment:
          crossAxisAlignment ??
          (axis == Axis.vertical
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center),
      spacing: spacing,
      children: [
        for (var i = 0; i < children.length; i++)
          FadeSlideIn(index: i, delayStep: delayStep, child: children[i]),
      ],
    );
  }
}
