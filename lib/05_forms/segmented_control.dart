import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../01_design_system/app_tokens.dart';

/// An iOS-style segmented control: a pill track with the selected segment
/// raised on a sliding white (or dark grey) thumb.
///
/// Source: StudyBuddies `IosSegmentedControl` (`core/widgets/ios_ui.dart`).
/// Material 3's `SegmentedButton` is the outlined Android equivalent; use
/// this when the design calls for the filled iOS look.
///
/// ```dart
/// SegmentedControl<Period>(
///   segments: const {Period.week: 'Week', Period.month: 'Month', Period.year: 'Year'},
///   selected: period,
///   onChanged: (p) => setState(() => period = p),
/// )
/// ```
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// Ordered value → label pairs. Map literals keep insertion order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final entry in segments.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: entry.key == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (entry.key == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(entry.key);
                  },
                  child: AnimatedContainer(
                    duration: Motion.short,
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == selected
                          ? (isDark ? scheme.surfaceBright : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: entry.key == selected && !isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: entry.key == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
