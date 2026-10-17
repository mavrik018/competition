/// Small, purposeful animations: a number that counts up to its value, an
/// animated success checkmark, and a horizontal shake for invalid input.
///
/// Newly written. Cookly and StudyBuddies used `flutter_animate` and Lottie
/// files for these moments; each is a few lines of plain Flutter. All three
/// respect the OS "reduce motion" setting.
///
/// ```dart
/// AnimatedCounter(value: totalSteps, format: (v) => '${v.round()} steps')
/// SuccessCheckmark(size: 96)                    // after a payment / save
///
/// final shake = ShakeController();
/// Shake(controller: shake, child: PinCodeField(...));
/// if (!ok) shake.shake();                        // wrong code
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Animates from the previous value to the new one whenever [value]
/// changes (from 0 on first build when [animateFromZero]).
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.format,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.animateFromZero = true,
  });

  final num value;

  /// Defaults to whole numbers.
  final String Function(double value)? format;
  final TextStyle? style;
  final Duration duration;
  final bool animateFromZero;

  @override
  Widget build(BuildContext context) {
    final formatter = format ?? (double v) => v.round().toString();
    final target = value.toDouble();
    return Semantics(
      label: formatter(target),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animateFromZero ? 0 : target, end: target),
        duration: _reduceMotion(context) ? Duration.zero : duration,
        curve: Curves.easeOutCubic,
        builder: (context, current, _) => Text(
          formatter(current),
          style: (style ?? DefaultTextStyle.of(context).style).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// A circle that draws itself, then a checkmark inside it.
class SuccessCheckmark extends StatefulWidget {
  const SuccessCheckmark({
    super.key,
    this.size = 80,
    this.color,
    this.duration = const Duration(milliseconds: 700),
    this.onCompleted,
  });

  final double size;
  final Color? color;
  final Duration duration;
  final VoidCallback? onCompleted;

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed) {
      if (_reduceMotion(context)) {
        _controller.value = 1;
        widget.onCompleted?.call();
      } else {
        HapticFeedback.mediumImpact();
        _controller.forward().whenComplete(() => widget.onCompleted?.call());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Done',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _CheckPainter(progress: _controller.value, color: color),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;

    // First 60%: the circle. Last 40%: the tick.
    final circle = (progress / 0.6).clamp(0.0, 1.0);
    canvas.drawArc(
      rect.deflate(stroke),
      -math.pi / 2,
      2 * math.pi * circle,
      false,
      paint,
    );

    final tick = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
    if (tick == 0) return;
    final a = Offset(size.width * 0.28, size.height * 0.52);
    final b = Offset(size.width * 0.44, size.height * 0.68);
    final c = Offset(size.width * 0.73, size.height * 0.36);
    final path = Path()..moveTo(a.dx, a.dy);
    // The tick has two strokes; the first takes 40% of its time.
    if (tick < 0.4) {
      final p = Offset.lerp(a, b, tick / 0.4)!;
      path.lineTo(p.dx, p.dy);
    } else {
      final p = Offset.lerp(b, c, (tick - 0.4) / 0.6)!;
      path
        ..lineTo(b.dx, b.dy)
        ..lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// Triggers a [Shake].
class ShakeController extends ChangeNotifier {
  /// Shakes the child once (and gives a haptic "error" buzz).
  void shake() => notifyListeners();
}

/// Shakes its child sideways when [controller] fires — the standard
/// "that's wrong" gesture for a rejected PIN or form.
class Shake extends StatefulWidget {
  const Shake({
    super.key,
    required this.controller,
    required this.child,
    this.distance = 12,
  });

  final ShakeController controller;
  final Widget child;
  final double distance;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_start);
  }

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_start);
      widget.controller.addListener(_start);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_start);
    _animation.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.heavyImpact();
    if (_reduceMotion(context)) return;
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        // Three decaying oscillations.
        final t = _animation.value;
        final dx = math.sin(t * math.pi * 6) * widget.distance * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
