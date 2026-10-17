import 'package:flutter/material.dart';

/// One bar in a [SimpleBarChart].
class BarDatum {
  const BarDatum(this.label, this.value);

  final String label;
  final num value;
}

/// A small vertical bar chart with an optional dashed target line — enough
/// for "this week at a glance" style summaries without a chart package.
///
/// Newly written. Cookly's `week_at_a_glance_card.dart` drew the same thing
/// with `fl_chart`, a large dependency for seven bars and one line. Bars are
/// ordinary widgets, so they animate, theme and expose semantics for free.
///
/// ```dart
/// SimpleBarChart(
///   data: [for (var i = 0; i < 7; i++) BarDatum('MTWTFSS'[i], totals[i])],
///   target: 2000,
///   highlightIndex: todayIndex,
/// )
/// ```
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.data,
    this.target,
    this.highlightIndex,
    this.height = 140,
    this.barColor,
    this.highlightColor,
    this.valueFormatter,
  });

  final List<BarDatum> data;

  /// Draws a dashed horizontal line at this value.
  final num? target;

  /// Index of the bar drawn in [highlightColor] (e.g. today).
  final int? highlightIndex;
  final double height;
  final Color? barColor;
  final Color? highlightColor;

  /// Formats values for screen readers. Defaults to `toString()`.
  final String Function(num value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxValue = chartMax(data.map((d) => d.value), target);
    final format = valueFormatter ?? (num v) => v.toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < data.length; i++)
                    Expanded(
                      child: Semantics(
                        label: '${data[i].label}: ${format(data[i].value)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: data[i].value / maxValue),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, fraction, _) => Container(
                              height: height * fraction.clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                color: i == highlightIndex
                                    ? (highlightColor ?? scheme.primary)
                                    : (barColor ??
                                          scheme.primary.withValues(
                                            alpha: 0.35,
                                          )),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (target != null && target! > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: height * (target! / maxValue),
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      size: const Size(double.infinity, 1.5),
                      painter: _DashedLinePainter(scheme.tertiary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    data[i].label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: i == highlightIndex
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: i == highlightIndex ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The value the top of the chart represents: the larger of the biggest bar
/// and the target, plus 15% headroom so the tallest bar never touches the
/// top. Never zero, so an all-zero chart still lays out.
double chartMax(Iterable<num> values, num? target) {
  var largest = target?.toDouble() ?? 0;
  for (final value in values) {
    if (value > largest) largest = value.toDouble();
  }
  return largest <= 0 ? 1 : largest * 1.15;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
