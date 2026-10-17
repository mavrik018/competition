/// A donut (ring) chart for parts of a whole — spending by category, time
/// by subject — with a centre label and a legend.
///
/// Newly written (no source app had one; Cookly's macro split used three
/// progress bars). The angle maths is in [donutSweeps] and unit-tested.
///
/// ```dart
/// DonutChart(
///   segments: const [
///     ChartSegment('Food', 420),
///     ChartSegment('Rent', 900),
///     ChartSegment('Fun', 150),
///   ],
///   centerLabel: '\$1,470',
/// )
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

class ChartSegment {
  const ChartSegment(this.label, this.value, {this.color});

  final String label;
  final num value;

  /// Defaults to a colour from the theme palette.
  final Color? color;
}

/// Sweep angle (radians) per value, proportional to its share of the total.
/// Negative values count as zero; an all-zero list gives all-zero sweeps.
List<double> donutSweeps(List<num> values) {
  final total = values.fold<double>(
    0,
    (sum, v) => sum + math.max(0, v.toDouble()),
  );
  if (total == 0) return List.filled(values.length, 0);
  return [
    for (final v in values) 2 * math.pi * math.max(0, v.toDouble()) / total,
  ];
}

/// [count] distinct colours derived from the theme, used when a segment
/// has none: the scheme's accent colours first, then the primary hue
/// rotated in steps. Duplicates (a minimal scheme reuses colours) are
/// skipped.
List<Color> chartPalette(ColorScheme scheme, int count) {
  final colors = <Color>[];
  for (final color in [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    scheme.error,
    scheme.primaryContainer,
    scheme.tertiaryContainer,
  ]) {
    if (colors.length < count && !colors.contains(color)) colors.add(color);
  }
  final base = HSLColor.fromColor(scheme.primary);
  for (var step = 1; colors.length < count && step < 360; step++) {
    final rotated = base
        .withHue((base.hue + 47.0 * step) % 360)
        .withSaturation(base.saturation.clamp(0.45, 0.85))
        .withLightness(base.lightness.clamp(0.35, 0.6))
        .toColor();
    if (!colors.contains(rotated)) colors.add(rotated);
  }
  return colors;
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 160,
    this.thickness = 22,
    this.centerLabel,
    this.centerCaption,
    this.showLegend = true,
    this.valueFormatter,
  });

  final List<ChartSegment> segments;
  final double size;
  final double thickness;
  final String? centerLabel;
  final String? centerCaption;
  final bool showLegend;
  final String Function(num value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = chartPalette(scheme, segments.length);
    final colors = [
      for (var i = 0; i < segments.length; i++) segments[i].color ?? palette[i],
    ];
    final total = segments.fold<num>(0, (sum, s) => sum + math.max(0, s.value));
    final format =
        valueFormatter ??
        (num v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    String percent(num v) =>
        total == 0 ? '0%' : '${(v / total * 100).round()}%';

    final ring = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              sweeps: donutSweeps([for (final s in segments) s.value]),
              colors: colors,
              thickness: thickness,
              track: scheme.surfaceContainerHighest,
            ),
          ),
          if (centerLabel != null)
            Padding(
              padding: EdgeInsets.all(thickness + 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerLabel!, style: theme.textTheme.titleLarge),
                    if (centerCaption != null)
                      Text(centerCaption!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label: [
        for (final s in segments)
          '${s.label} ${format(s.value)}, ${percent(s.value)}',
      ].join('; '),
      excludeSemantics: true,
      child: !showLegend
          ? ring
          : Wrap(
              spacing: Gap.lg,
              runSpacing: Gap.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ring,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < segments.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors[i],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Text(
                              '${segments[i].label}  ',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              '${format(segments[i].value)} · ${percent(segments[i].value)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.sweeps,
    required this.colors,
    required this.thickness,
    required this.track,
  });

  final List<double> sweeps;
  final List<Color> colors;
  final double thickness;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(thickness / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);

    // A small gap between segments keeps adjacent colours readable.
    final visible = sweeps.where((s) => s > 0).length;
    final gap = visible > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < sweeps.length; i++) {
      if (sweeps[i] <= 0) continue;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0, sweeps[i] - gap),
        false,
        paint..color = colors[i],
      );
      start += sweeps[i];
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.sweeps != sweeps || old.colors != colors;
}
