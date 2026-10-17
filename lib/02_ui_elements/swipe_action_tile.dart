import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../01_design_system/app_tokens.dart';

/// One action revealed behind a [SwipeActionTile].
class SwipeAction {
  const SwipeAction({
    required this.icon,
    required this.color,
    required this.onTriggered,
    this.label,
    this.dismisses = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTriggered;

  /// Screen-reader label for the action button.
  final String? label;

  /// When true the row collapses (shrink + fade) before [onTriggered] runs —
  /// use it for delete/archive. Otherwise the row slides closed afterwards.
  final bool dismisses;
}

/// A list row that slides sideways to reveal an action button underneath:
/// swipe right for [startAction], left for [endAction].
///
/// Source: TaskFlow `swipe_action_wrapper.dart` (complete/delete on task
/// cards). Generalised to any two actions and moved onto a single unbounded
/// [AnimationController] instead of a hand-driven offset plus listener.
///
/// Behaviour kept from the source: rubber-band resistance past the reveal
/// width, a light haptic when crossing the halfway threshold, snap open or
/// closed on release, and an animated collapse for destructive actions.
///
/// ```dart
/// SwipeActionTile(
///   startAction: SwipeAction(icon: Icons.check, color: Colors.green, onTriggered: complete),
///   endAction: SwipeAction(icon: Icons.delete, color: Colors.red, dismisses: true, onTriggered: delete),
///   child: TaskTile(task),
/// )
/// ```
class SwipeActionTile extends StatefulWidget {
  const SwipeActionTile({
    super.key,
    required this.child,
    this.startAction,
    this.endAction,
    this.revealWidth = 80,
    this.borderRadius = Radii.md,
  });

  final Widget child;
  final SwipeAction? startAction;
  final SwipeAction? endAction;

  /// How far the row slides open to show an action.
  final double revealWidth;
  final double borderRadius;

  @override
  State<SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<SwipeActionTile>
    with TickerProviderStateMixin {
  // Horizontal offset of the row in pixels; positive = slid right.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  // 1 = full height, 0 = collapsed (for dismissing actions).
  late final AnimationController _size = AnimationController(
    vsync: this,
    duration: Motion.short,
    value: 1,
  );
  bool _pastThreshold = false;

  @override
  void dispose() {
    _offset.dispose();
    _size.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    var next = _offset.value + (details.primaryDelta ?? 0);
    if (next > 0 && widget.startAction == null) next = 0;
    if (next < 0 && widget.endAction == null) next = 0;

    // Rubber-band: beyond the reveal width, movement is damped to 30%.
    final limit = widget.revealWidth;
    if (next.abs() > limit) {
      next = next.sign * (limit + (next.abs() - limit) * 0.3);
    }
    _offset.value = next;

    final past = next.abs() >= limit / 2;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      if (past) HapticFeedback.lightImpact();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final open = _offset.value.abs() >= widget.revealWidth / 2;
    unawaited(_snapTo(open ? _offset.value.sign * widget.revealWidth : 0));
    _pastThreshold = false;
  }

  Future<void> _snapTo(double target) => _offset.animateTo(
    target,
    duration: Motion.short,
    curve: Curves.easeOutCubic,
  );

  Future<void> _trigger(SwipeAction action) async {
    if (action.dismisses) {
      unawaited(HapticFeedback.heavyImpact());
      await _size.reverse();
      action.onTriggered();
    } else {
      unawaited(HapticFeedback.mediumImpact());
      action.onTriggered();
      await _snapTo(0);
    }
  }

  Widget _actionButton(SwipeAction action, {required bool isStart}) {
    final radius = Radius.circular(widget.borderRadius);
    return Semantics(
      button: true,
      label: action.label,
      child: GestureDetector(
        onTap: () => unawaited(_trigger(action)),
        child: Container(
          width: widget.revealWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: action.color,
            borderRadius: isStart
                ? BorderRadius.horizontal(left: radius)
                : BorderRadius.horizontal(right: radius),
          ),
          child: Icon(action.icon, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Swiping is invisible to screen readers, so the same actions are also
    // offered as custom semantics actions.
    final semanticActions = <CustomSemanticsAction, VoidCallback>{
      for (final action in [widget.startAction, widget.endAction])
        if (action != null)
          CustomSemanticsAction(label: action.label ?? 'Action'): () =>
              unawaited(_trigger(action)),
    };

    return Semantics(
      customSemanticsActions: semanticActions,
      child: _buildSwipeable(),
    );
  }

  Widget _buildSwipeable() {
    return SizeTransition(
      sizeFactor: _size,
      child: FadeTransition(
        opacity: _size,
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) {
            final dx = _offset.value;
            return Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      if (dx > 0 && widget.startAction != null)
                        _actionButton(widget.startAction!, isStart: true),
                      const Spacer(),
                      if (dx < 0 && widget.endAction != null)
                        _actionButton(widget.endAction!, isStart: false),
                    ],
                  ),
                ),
                GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  ),
                ),
              ],
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
