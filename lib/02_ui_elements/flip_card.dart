import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A card that turns over in 3D between a [front] and a [back].
///
/// Source: the flashcard flip inside StudyBuddies
/// `spaced_repetition_screen.dart` (a 1,500-line screen). Extracted into a
/// declarative widget: the parent owns [showBack] and the card animates to
/// match it.
///
/// ```dart
/// FlipCard(
///   key: ValueKey(card.id), // a new card starts face-up, without animating
///   showBack: revealed,
///   onTap: () => setState(() => revealed = !revealed),
///   front: Center(child: Text(card.question)),
///   back: Center(child: Text(card.answer)),
/// )
/// ```
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.showBack,
    this.onTap,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget front;
  final Widget back;

  /// Which face should be up. Changing it animates the turn.
  final bool showBack;
  final VoidCallback? onTap;
  final Duration duration;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  // 0 = front facing the viewer, 1 = back facing the viewer.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.showBack ? 1 : 0,
  );
  late final Animation<double> _turn = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBack != widget.showBack) {
      widget.showBack ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final pastHalfway = _turn.value >= 0.5;
          // Past 90° the back is the visible face. It is pre-rotated by 180°
          // so its content is not mirrored once the card finishes turning.
          final face = pastHalfway
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: widget.back,
                )
              : widget.front;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(_turn.value * math.pi),
            child: Semantics(
              button: widget.onTap != null,
              hint: pastHalfway ? 'Showing back' : 'Showing front',
              child: face,
            ),
          );
        },
      ),
    );
  }
}
