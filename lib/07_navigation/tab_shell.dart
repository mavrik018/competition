import 'package:flutter/material.dart';

/// One tab of a [TabShell].
class TabDestination {
  const TabDestination({
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final WidgetBuilder builder;
}

/// The signed-in app frame: a bottom [NavigationBar] (or a side
/// [NavigationRail] on wide windows) whose tabs keep their
/// state (scroll position, form input, nested navigation) when you switch
/// away and back.
///
/// Source: Couple `app_shell.dart` (`IndexedStack` + `HeroMode` so only the
/// visible tab's heroes animate) and StudyBuddies `root_shell.dart`. Added:
/// tabs are built the first time they are opened rather than all at launch
/// (an `IndexedStack` builds every child up front, which starts every tab's
/// data loading at once), and re-tapping the current tab calls [onReselect]
/// — the usual hook for "scroll to top".
///
/// ```dart
/// TabShell(
///   destinations: [
///     TabDestination(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home, builder: (_) => const HomePage()),
///     TabDestination(label: 'Library', icon: Icons.book_outlined, builder: (_) => const LibraryPage()),
///   ],
/// )
/// ```
class TabShell extends StatefulWidget {
  const TabShell({
    super.key,
    required this.destinations,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onReselect,
    this.railBreakpoint = 840,
  }) : assert(destinations.length >= 2);

  final List<TabDestination> destinations;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;
  final ValueChanged<int>? onReselect;

  /// From this window width up, a side [NavigationRail] replaces the bottom
  /// bar (Material 3's "expanded" size class). `double.infinity` disables it.
  final double railBreakpoint;

  @override
  State<TabShell> createState() => TabShellState();
}

/// Public so a parent holding a `GlobalKey<TabShellState>` can switch tabs
/// (e.g. after a deep link).
class TabShellState extends State<TabShell> {
  late int _index = widget.initialIndex;
  late final Set<int> _visited = {widget.initialIndex};

  int get index => _index;

  void select(int index) {
    if (index == _index) {
      widget.onReselect?.call(index);
      return;
    }
    setState(() {
      _index = index;
      _visited.add(index);
    });
    widget.onIndexChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = widget.destinations;
    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < destinations.length; i++)
          HeroMode(
            enabled: i == _index,
            child: _visited.contains(i)
                ? Builder(builder: destinations[i].builder)
                : const SizedBox.shrink(),
          ),
      ],
    );

    final useRail = MediaQuery.sizeOf(context).width >= widget.railBreakpoint;
    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(
                      destination.selectedIcon ?? destination.icon,
                    ),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon ?? destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
