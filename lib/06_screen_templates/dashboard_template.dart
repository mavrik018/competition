/// A home/dashboard screen: greeting header, a responsive grid of metric
/// cards, an optional highlight banner, and titled sections — with pull to
/// refresh.
///
/// Newly written from the pattern shared by StudyBuddies' `home_tab.dart`
/// (1,811 lines), Cookly's `home_screen.dart` and Couple's `home_page.dart`:
/// all three are "greeting + stats + a stack of sections", rebuilt from
/// toolkit parts so a new dashboard is a list of widgets.
///
/// ```dart
/// DashboardTemplate(
///   greeting: 'Good morning, Sam',
///   subtitle: 'You have 3 tasks due today',
///   avatar: const CircleAvatar(child: Text('S')),
///   stats: const [
///     StatCard(label: 'Done this week', value: '12', delta: 0.2),
///     StatCard(label: 'Focus time', value: '5h 10m'),
///   ],
///   highlight: StatusBanner(kind: StatusKind.info, message: '2 overdue tasks'),
///   sections: [
///     DashboardSection(title: 'Today', actionLabel: 'See all', onAction: openTasks, child: TodayList()),
///     DashboardSection(title: 'Insights', child: InsightList(insights)),
///   ],
///   onRefresh: () => ref.refresh(dashboardProvider.future),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../02_ui_elements/section_header.dart';
import 'responsive_layout.dart';

class DashboardSection {
  const DashboardSection({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
}

class DashboardTemplate extends StatelessWidget {
  const DashboardTemplate({
    super.key,
    required this.greeting,
    this.subtitle,
    this.avatar,
    this.actions = const [],
    this.stats = const [],
    this.highlight,
    this.sections = const [],
    this.onRefresh,
    this.minStatWidth = 150,
  });

  final String greeting;
  final String? subtitle;
  final Widget? avatar;

  /// Icon buttons in the header (notifications, search…).
  final List<Widget> actions;

  /// Usually `StatCard`s; laid out in a responsive grid.
  final List<Widget> stats;

  /// A full-width widget under the stats (e.g. a `StatusBanner`).
  final Widget? highlight;
  final List<DashboardSection> sections;
  final Future<void> Function()? onRefresh;
  final double minStatWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.gutter,
            Gap.md,
            Gap.gutter,
            Gap.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        greeting,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ...actions,
              if (avatar != null) ...[const SizedBox(width: Gap.sm), avatar!],
            ],
          ),
        ),
        if (stats.isNotEmpty)
          Padding(
            padding: Insets.page,
            child: ResponsiveGrid(
              minItemWidth: minStatWidth,
              spacing: Gap.md - 4,
              children: stats,
            ),
          ),
        if (highlight != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.md,
              Gap.gutter,
              0,
            ),
            child: highlight,
          ),
        for (final section in sections) ...[
          const SizedBox(height: Gap.lg),
          SectionHeader(
            title: section.title,
            icon: section.icon,
            actionLabel: section.actionLabel,
            onAction: section.onAction,
          ),
          const SizedBox(height: Gap.sm),
          Padding(padding: Insets.page, child: section.child),
        ],
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}
