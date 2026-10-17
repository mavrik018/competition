import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One segment of a [SpinWheel].
class WheelSlice {
  const WheelSlice({required this.label, required this.color});

  final String label;
  final Color color;
}

/// Lets a parent start a spin without owning the animation.
class SpinWheelController extends ChangeNotifier {
  int? _requested;
  bool _spinning = false;

  bool get isSpinning => _spinning;

  /// Spins so that slice [index] ends under the pointer. Ignored while a spin
  /// is already running.
  void spinTo(int index) {
    if (_spinning) return;
    _requested = index;
    notifyListeners();
  }

  /// Spins to a random slice of [sliceCount].
  void spinRandom(int sliceCount, [math.Random? random]) =>
      spinTo((random ?? math.Random()).nextInt(sliceCount));
}

/// A prize/decision wheel that really spins, ticks past each slice with a
/// haptic, and reports the slice it settles on.
///
/// Source: Cookly `roulette_wheel.dart` (693 lines with a metallic bezel,
/// brass pegs, a glass hub and image badges). Kept: the controller API, the
/// ease-out spin with several full turns, per-slice haptic ticks and the
/// settle callback. Dropped: the decorative layers.
///
/// Fixed in extraction: the source computed the end angle as if every spin
/// started from 0. From the second spin on, the wheel stopped on a different
/// slice from the one it reported. [spinEndAngle] accounts for the resting
/// angle, and the test suite spins repeatedly to prove it.
///
/// ```dart
/// final controller = SpinWheelController();
/// SpinWheel(slices: slices, controller: controller, onSettled: (i) => …);
/// FilledButton(onPressed: () => controller.spinRandom(slices.length), …);
/// ```
class SpinWheel extends StatefulWidget {
  const SpinWheel({
    super.key,
    required this.slices,
    required this.controller,
    required this.onSettled,
    this.size = 260,
    this.duration = const Duration(milliseconds: 3200),
  }) : assert(slices.length >= 2, 'A wheel needs at least two slices');

  final List<WheelSlice> slices;
  final SpinWheelController controller;

  /// Called with the index of the slice under the pointer once it stops.
  final ValueChanged<int> onSettled;
  final double size;
  final Duration duration;

  @override
  State<SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<SpinWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Animation<double> _angle = const AlwaysStoppedAnimation(0);
  double _restingAngle = 0;
  int? _target;
  int _lastTickSlice = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onRequest);
    _spin.addListener(_onTick);
    _spin.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(SpinWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onRequest);
      widget.controller.addListener(_onRequest);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onRequest);
    _spin.dispose();
    super.dispose();
  }

  void _onRequest() {
    final index = widget.controller._requested;
    if (index == null || _spin.isAnimating) return;
    widget.controller
      .._requested = null
      .._spinning = true;

    final end = spinEndAngle(
      restingAngle: _restingAngle,
      index: index,
      sliceCount: widget.slices.length,
    );
    _target = index;
    _lastTickSlice = sliceUnderPointer(_restingAngle, widget.slices.length);
    _angle = Tween<double>(
      begin: _restingAngle,
      end: end,
    ).animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutQuart));
    _restingAngle = end;
    _spin.forward(from: 0);
  }

  void _onTick() {
    final slice = sliceUnderPointer(_angle.value, widget.slices.length);
    if (slice != _lastTickSlice) {
      _lastTickSlice = slice;
      HapticFeedback.selectionClick();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final index = _target;
    _target = null;
    widget.controller._spinning = false;
    if (index == null) return;
    HapticFeedback.mediumImpact();
    widget.onSettled(index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const pointerHeight = 28.0;

    return Semantics(
      label: 'Spinning wheel with ${widget.slices.length} options',
      child: SizedBox(
        width: widget.size,
        height: widget.size + pointerHeight / 2,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: pointerHeight / 2,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, child) =>
                    Transform.rotate(angle: _angle.value, child: child),
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _WheelPainter(
                    widget.slices,
                    Theme.of(context).textTheme.labelMedium!,
                  ),
                ),
              ),
            ),
            Positioned(
              top: pointerHeight / 2 + widget.size / 2 - 22,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant, width: 3),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(26, pointerHeight),
              painter: _PointerPainter(scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Index of the slice under a pointer fixed at 12 o'clock when the wheel is
/// rotated clockwise by [angle] radians. Slice 0 starts at 12 o'clock and
/// slices run clockwise.
int sliceUnderPointer(double angle, int sliceCount) {
  final sweep = 2 * math.pi / sliceCount;
  // Rotating the wheel clockwise by θ brings the wheel's own angle −θ under
  // the pointer.
  final underPointer = (-angle) % (2 * math.pi);
  return (underPointer / sweep).floor() % sliceCount;
}

/// The angle to animate to so slice [index]'s centre lands under the pointer,
/// after [turns] full turns, starting from [restingAngle].
double spinEndAngle({
  required double restingAngle,
  required int index,
  required int sliceCount,
  int turns = 4,
}) {
  final sweep = 2 * math.pi / sliceCount;
  final targetMod = (2 * math.pi - (index + 0.5) * sweep) % (2 * math.pi);
  final currentMod = restingAngle % (2 * math.pi);
  // Forward distance (0..2π) from where the wheel rests to the target.
  final forward = (targetMod - currentMod) % (2 * math.pi);
  return restingAngle + turns * 2 * math.pi + forward;
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.slices, this.labelStyle);

  final List<WheelSlice> slices;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    final sweep = 2 * math.pi / slices.length;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    for (var i = 0; i < slices.length; i++) {
      final start = -math.pi / 2 + i * sweep;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = slices[i].color,
      );
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label along the slice's centre line, reading outwards.
      final text = TextPainter(
        text: TextSpan(
          text: slices[i].label,
          style: labelStyle.copyWith(
            color:
                ThemeData.estimateBrightnessForColor(slices[i].color) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius * 0.62);

      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(start + sweep / 2);
      text.paint(canvas, Offset(radius * 0.3, -text.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.slices != slices || old.labelStyle != labelStyle;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => old.color != color;
}
