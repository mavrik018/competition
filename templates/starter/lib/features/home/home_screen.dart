// Dashboard: counts, the most urgent item (rule-based priority score, with
// its reasons), and what's next. Replace the stats with your domain's KPIs.

import 'package:{{app_name}}/toolkit/02_ui_elements/cards.dart';
import 'package:{{app_name}}/toolkit/03_feedback/state_views.dart';
import 'package:{{app_name}}/toolkit/06_screen_templates/dashboard_template.dart';
import 'package:{{app_name}}/toolkit/13_smart_features/priority_scoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../items/item.dart';
import '../items/items_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider).value ?? const <Item>[];
    final now = DateTime.now();
    final open = [
      for (final i in items)
        if (!i.done) i,
    ];
    final overdue = open.where((i) => i.due != null && i.due!.isBefore(now));
    final ranked = rankByPriority(open, (i) => i.priorityInput, now: now);

    return DashboardTemplate(
      greeting: 'Welcome back',
      subtitle: open.isEmpty
          ? 'All caught up'
          : '${open.length} open item${open.length == 1 ? '' : 's'}',
      stats: [
        StatCard(label: 'Open', value: '${open.length}', icon: Icons.inbox),
        StatCard(
          label: 'Done',
          value: '${items.length - open.length}',
          icon: Icons.check_circle_outline,
        ),
        StatCard(
          label: 'Overdue',
          value: '${overdue.length}',
          icon: Icons.warning_amber,
        ),
      ],
      highlight: ranked.isEmpty
          ? null
          : ActionCard(
              title: 'Next: ${ranked.first.$1.title}',
              subtitle: ranked.first.$2.reasons.isEmpty
                  ? 'Highest priority score (${ranked.first.$2.score})'
                  : ranked.first.$2.reasons.join(' · '),
              icon: Icons.flag_outlined,
            ),
      sections: [
        DashboardSection(
          title: 'Up next',
          icon: Icons.list_alt,
          child: ranked.isEmpty
              ? const EmptyView(
                  icon: Icons.celebration_outlined,
                  title: 'Nothing open',
                  message: 'Add items in the Items tab.',
                  compact: true,
                )
              : Column(
                  children: [
                    for (final (item, score) in ranked.take(3))
                      ListTile(
                        leading: CircleAvatar(child: Text('${score.score}')),
                        title: Text(item.title),
                        subtitle: Text(score.band.name),
                      ),
                  ],
                ),
        ),
      ],
      onRefresh: () => ref.read(itemsProvider.notifier).reload(),
    );
  }
}
