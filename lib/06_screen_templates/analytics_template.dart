/// An analytics/report screen: a period switcher (Week / Month / Year…),
/// KPI cards, a trend chart, a breakdown donut and a list of insights.
///
/// Newly written from the shape of StudyBuddies' `progress_analytics_screen`
/// (959 lines) and Cookly's calorie statistics tab (876 lines). The screen
/// renders; computing the numbers stays outside — feed it from `trends.dart`
/// and `insights.dart` (13).
///
/// ```dart
/// AnalyticsTemplate(
///   title: 'Spending',
///   periods: {
///     'Week': AnalyticsSnapshot(
///       kpis: [StatCard(label: 'Spent', value: '\$312', delta: -0.08, higherIsBetter: false)],
///       trend: weekTotals, trendLabels: const ['M','T','W','T','F','S','S'],
///       breakdown: [ChartSegment('Food', 120), ChartSegment('Travel', 80)],
///       insights: [for (final i in insightsFor(week)) InsightCard(insight: i)],
///     ),
///     'Month': ...,
///   },
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../02_ui_elements/donut_chart.dart';
import '../02_ui_elements/line_chart.dart';
import '../02_ui_elements/section_header.dart';
import '../03_feedback/state_views.dart';
import '../05_forms/segmented_control.dart';
import 'responsive_layout.dart';

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    this.kpis = const [],
    this.trend = const [],
    this.trendLabels,
    this.comparisonTrend,
    this.trendTitle = 'Trend',
    this.breakdown = const [],
    this.breakdownTitle = 'Breakdown',
    this.breakdownCenterLabel,
    this.insights = const [],
  });

  /// Usually `StatCard`s.
  final List<Widget> kpis;
  final List<num> trend;
  final List<String>? trendLabels;

  /// The previous period, drawn dashed.
  final List<num>? comparisonTrend;
  final String trendTitle;
  final List<ChartSegment> breakdown;
  final String breakdownTitle;
  final String? breakdownCenterLabel;

  /// Usually `InsightCard`s from `13_smart_features/insights.dart`.
  final List<Widget> insights;

  bool get isEmpty =>
      kpis.isEmpty && trend.isEmpty && breakdown.isEmpty && insights.isEmpty;
}

class AnalyticsTemplate extends StatefulWidget {
  const AnalyticsTemplate({
    super.key,
    required this.title,
    required this.periods,
    this.initialPeriod,
  });

  final String title;

  /// Ordered period label → data. Map literals keep insertion order.
  final Map<String, AnalyticsSnapshot> periods;
  final String? initialPeriod;

  @override
  State<AnalyticsTemplate> createState() => _AnalyticsTemplateState();
}

class _AnalyticsTemplateState extends State<AnalyticsTemplate> {
  late String _period = widget.initialPeriod ?? widget.periods.keys.first;

  @override
  Widget build(BuildContext context) {
    final data = widget.periods[_period] ?? const AnalyticsSnapshot();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          if (widget.periods.length > 1)
            Padding(
              padding: Insets.page,
              child: SegmentedControl<String>(
                segments: {for (final p in widget.periods.keys) p: p},
                selected: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
            ),
          if (data.isEmpty)
            const EmptyView(
              icon: Icons.insights_outlined,
              title: 'No data for this period yet',
            ),
          if (data.kpis.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Padding(
              padding: Insets.page,
              child: ResponsiveGrid(minItemWidth: 150, children: data.kpis),
            ),
          ],
          if (data.trend.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            SectionHeader(title: data.trendTitle, icon: Icons.show_chart),
            const SizedBox(height: Gap.sm),
            Padding(
              padding: Insets.page,
              child: Card(
                child: Padding(
                  padding: Insets.card,
                  child: SimpleLineChart(
                    values: data.trend,
                    labels: data.trendLabels,
                    comparison: data.comparisonTrend,
                  ),
                ),
              ),
            ),
          ],
          if (data.breakdown.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            SectionHeader(title: data.breakdownTitle, icon: Icons.donut_large),
            const SizedBox(height: Gap.sm),
            Padding(
              padding: Insets.page,
              child: Card(
                child: Padding(
                  padding: Insets.card,
                  child: DonutChart(
                    segments: data.breakdown,
                    centerLabel: data.breakdownCenterLabel,
                  ),
                ),
              ),
            ),
          ],
          if (data.insights.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            const SectionHeader(
              title: 'Insights',
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: Gap.sm),
            for (final insight in data.insights)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.gutter,
                  0,
                  Gap.gutter,
                  Gap.sm,
                ),
                child: insight,
              ),
          ],
        ],
      ),
    );
  }
}
