import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact − / + control for small whole numbers (servings, quantity,
/// minutes).
///
/// Source: StudyBuddies `IosStepper` / Cookly `CooklyStepper`
/// (`core/widgets/ios_ui.dart`). Adds [step] and a semantic value so screen
/// readers announce the number and can adjust it.
///
/// ```dart
/// NumberStepper(value: servings, min: 1, max: 12, onChanged: setServings)
/// ```
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.step = 1,
  }) : assert(min <= max);

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  bool get _canDecrease => value - step >= min;
  bool get _canIncrease => value + step <= max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      value: '$value',
      increasedValue: _canIncrease ? '${value + step}' : null,
      decreasedValue: _canDecrease ? '${value - step}' : null,
      onIncrease: _canIncrease ? () => onChanged(value + step) : null,
      onDecrease: _canDecrease ? () => onChanged(value - step) : null,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(
              context,
              icon: CupertinoIcons.minus,
              onTap: _canDecrease ? () => onChanged(value - step) : null,
            ),
            Container(width: 1, height: 22, color: scheme.outlineVariant),
            _button(
              context,
              icon: CupertinoIcons.plus,
              onTap: _canIncrease ? () => onChanged(value + step) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        child: SizedBox(
          width: 44,
          height: 34,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
