import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A circular progress ring with an optional label in the middle.
///
/// Source: StudyBuddies `core/widgets/radial_gauge.dart` — kept nearly as-is.
/// It draws with a [CustomPainter] rather than a chart package, and scales
/// the centre label down to fit inside the ring so a long value or a large
/// system text size cannot overflow it.
///
/// ```dart
/// RadialGauge(
///   value: 0.72,
///   size: 120,
///   child: Text('72%'),
/// )
/// ```
class RadialGauge extends StatelessWidget {
  const RadialGauge({
    super.key,
    required this.value,
    required this.size,
    this.color,
    this.trackColor,
    this.strokeWidth = 10,
    this.child,
    this.semanticLabel,
  });

  /// Progress from 0.0 to 1.0. Values outside the range are clamped.
  final double value;
  final double size;

  /// Defaults to the theme's primary colour.
  final Color? color;

  /// Defaults to a faint version of the primary colour.
  final Color? trackColor;
  final double strokeWidth;
  final Widget? child;

  /// Defaults to "N percent".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final ringColor = color ?? scheme.primary;

    return Semantics(
      label: semanticLabel ?? '${(clamped * 100).round()} percent',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RadialGaugePainter(
                value: clamped,
                color: ringColor,
                trackColor: trackColor ?? ringColor.withValues(alpha: 0.15),
                strokeWidth: strokeWidth,
              ),
            ),
            if (child != null)
              Padding(
                padding: EdgeInsets.all(strokeWidth + 2),
                child: FittedBox(fit: BoxFit.scaleDown, child: child),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  _RadialGaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = trackColor);
    if (value <= 0) return;

    // Start at 12 o'clock and sweep clockwise.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RadialGaugePainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
