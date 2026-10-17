/// A line chart for a time series (with optional area fill, dots, a
/// comparison series and min/max labels) and a tiny inline sparkline.
///
/// Newly written, completing the chart set with `SimpleBarChart`,
/// `RadialGauge` and `DonutChart`. Cookly used `fl_chart` for its 7-day
/// trend; for one or two series a `CustomPainter` is ~150 lines with no
/// dependency, and the maths ([plotPoints]) is unit-tested.
///
/// ```dart
/// SimpleLineChart(
///   values: weeklyMinutes,                      // List<num>
///   labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
///   comparison: lastWeekMinutes,                // dashed, optional
///   valueFormatter: (v) => '${v.round()} min',
/// )
/// Sparkline(values: last30Days, width: 80, height: 24)
/// ```
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Maps [values] into a [size] box, left to right, with [minY] at the
/// bottom and [maxY] at the top. A single value sits in the middle; a flat
/// series sits halfway up instead of dividing by zero.
List<Offset> plotPoints(
  List<num> values,
  Size size, {
  double? minY,
  double? maxY,
}) {
  if (values.isEmpty) return const [];
  final low = minY ?? values.map((v) => v.toDouble()).reduce(math.min);
  final high = maxY ?? values.map((v) => v.toDouble()).reduce(math.max);
  final span = high - low;
  final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);
  return [
    for (var i = 0; i < values.length; i++)
      Offset(
        values.length == 1 ? size.width / 2 : i * step,
        span == 0
            ? size.height / 2
            : size.height - ((values[i] - low) / span) * size.height,
      ),
  ];
}

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.values,
    this.labels,
    this.comparison,
    this.height = 160,
    this.color,
    this.showArea = true,
    this.showDots = true,
    this.startAtZero = true,
    this.valueFormatter,
    this.semanticLabel,
  });

  final List<num> values;

  /// X-axis labels, one per value. Long lists show only every n-th label.
  final List<String>? labels;

  /// A second series drawn dashed (e.g. the previous period).
  final List<num>? comparison;
  final double height;
  final Color? color;
  final bool showArea;
  final bool showDots;

  /// Include 0 in the y range so small changes don't look dramatic.
  final bool startAtZero;
  final String Function(num value)? valueFormatter;

  /// Defaults to "Line chart, from A to B, high C".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lineColor = color ?? scheme.primary;
    final format =
        valueFormatter ??
        (num v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    final all = [...values, ...?comparison];
    if (all.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No data')),
      );
    }
    final dataMin = all.map((v) => v.toDouble()).reduce(math.min);
    final maxY = all.map((v) => v.toDouble()).reduce(math.max);
    final minY = startAtZero ? math.min(0.0, dataMin) : dataMin;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final description =
        semanticLabel ??
        'Line chart, from ${format(values.first)} to ${format(values.last)}, '
            'high ${format(values.map((v) => v.toDouble()).reduce(math.max))}';

    return Semantics(
      label: description,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(format(maxY), style: labelStyle),
                    Text(format(minY), style: labelStyle),
                  ],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: CustomPaint(
                    painter: _LinePainter(
                      values: values,
                      comparison: comparison,
                      minY: minY,
                      maxY: maxY,
                      color: lineColor,
                      comparisonColor: scheme.outline,
                      gridColor: scheme.outlineVariant.withValues(alpha: 0.5),
                      showArea: showArea,
                      showDots: showDots,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (labels != null && labels!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                // Lines up with the chart area (past the y labels).
                SizedBox(
                  width: _yLabelWidth(format(maxY), format(minY), labelStyle),
                ),
                Expanded(
                  child: _XLabels(labels: labels!, style: labelStyle),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double _yLabelWidth(String a, String b, TextStyle? style) {
    double width(String text) => (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout()).width;
    return math.max(width(a), width(b)) + 6;
  }
}

class _XLabels extends StatelessWidget {
  const _XLabels({required this.labels, required this.style});

  final List<String> labels;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    // At most ~7 labels; show every n-th one.
    final every = (labels.length / 7).ceil().clamp(1, labels.length);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < labels.length; i++)
          if (i % every == 0 || i == labels.length - 1)
            Text(labels[i], style: style),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.comparison,
    required this.minY,
    required this.maxY,
    required this.color,
    required this.comparisonColor,
    required this.gridColor,
    required this.showArea,
    required this.showDots,
  });

  final List<num> values;
  final List<num>? comparison;
  final double minY;
  final double maxY;
  final Color color;
  final Color comparisonColor;
  final Color gridColor;
  final bool showArea;
  final bool showDots;

  @override
  void paint(Canvas canvas, Size size) {
    // Three faint horizontal grid lines.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (comparison != null && comparison!.isNotEmpty) {
      final points = plotPoints(comparison!, size, minY: minY, maxY: maxY);
      _drawDashed(
        canvas,
        points,
        Paint()
          ..color = comparisonColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    final points = plotPoints(values, size, minY: minY, maxY: maxY);
    if (points.isEmpty) return;
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    if (showArea && points.length > 1) {
      final area = Path.from(line)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0),
          ]),
      );
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (showDots) {
      final dot = Paint()..color = color;
      for (final p in points) {
        canvas.drawCircle(p, 3, dot);
      }
      // Emphasise the latest value.
      canvas.drawCircle(points.last, 5, dot);
    }
  }

  void _drawDashed(Canvas canvas, List<Offset> points, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final length = (b - a).distance;
      if (length == 0) continue;
      final direction = (b - a) / length;
      for (var d = 0.0; d < length; d += dash + gap) {
        final start = a + direction * d;
        final end = a + direction * math.min(d + dash, length);
        canvas.drawLine(start, end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.comparison != comparison ||
      old.color != color ||
      old.minY != minY ||
      old.maxY != maxY;
}

/// A tiny line with no axes — for table rows and stat cards.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width = 80,
    this.height = 24,
    this.color,
  });

  final List<num> values;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _LinePainter(
            values: values,
            comparison: null,
            minY: values.isEmpty
                ? 0
                : values.map((v) => v.toDouble()).reduce(math.min),
            maxY: values.isEmpty
                ? 0
                : values.map((v) => v.toDouble()).reduce(math.max),
            color: color ?? Theme.of(context).colorScheme.primary,
            comparisonColor: Colors.transparent,
            gridColor: Colors.transparent,
            showArea: false,
            showDots: false,
          ),
        ),
      ),
    );
  }
}
