import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

/// Shimmering placeholder blocks shaped like the content they stand in for,
/// so the layout does not jump when data arrives.
///
/// Source: Cookly `ShimmerBox` / `ShimmerList` / `ShimmerCardRow`
/// (`core/widgets/states.dart`). The source used the `shimmer` package; this
/// version draws the same moving highlight with one [AnimationController] and
/// a [ShaderMask], so it needs no dependency.
///
/// ```dart
/// isLoading ? const SkeletonList(rows: 4) : NotesList(notes)
/// ```
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1400),
  });

  /// Everything under this widget gets the moving highlight. Wrap a whole
  /// skeleton layout once rather than each box, so the sweep stays in sync.
  final Widget child;
  final Duration period;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surfaceContainerLow;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Slide a soft band from left (-1) to right (+1) across the bounds.
        final dx = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(dx - 1, 0),
            end: Alignment(dx + 1, 0),
            colors: [base, highlight, base],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A single placeholder block. Combine several inside one [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = Radii.md,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A shimmering vertical list of row placeholders.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 3, this.rowHeight = 72});

  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Shimmer(
        child: Column(
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) const SizedBox(height: Gap.md - 4),
              SkeletonBox(height: rowHeight),
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmering horizontal row of card placeholders, for carousels.
class SkeletonCardRow extends StatelessWidget {
  const SkeletonCardRow({
    super.key,
    this.height = 200,
    this.cardWidth = 240,
    this.cards = 3,
  });

  final double height;
  final double cardWidth;
  final int cards;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        height: height,
        child: Shimmer(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: Insets.page,
            itemCount: cards,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.md - 4),
            itemBuilder: (_, _) =>
                SkeletonBox(width: cardWidth, height: height, radius: Radii.xl),
          ),
        ),
      ),
    );
  }
}
