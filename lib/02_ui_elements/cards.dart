/// Three card shapes that cover most dashboards and lists: a metric card
/// with a trend delta, a tappable action/info card, and an image card.
///
/// Newly written. The source apps built each dashboard tile by hand
/// (Cookly's `KitchenStatsCard`, StudyBuddies' home tiles, Couple's
/// `RelationshipStatsCard`); these are their common denominators.
///
/// ```dart
/// StatCard(label: 'Study time', value: '4h 20m', icon: Icons.timer, delta: 0.12)
/// ActionCard(icon: Icons.upload_file, title: 'Import notes', subtitle: 'PDF or photo', onTap: import)
/// ImageCard(image: NetworkImage(recipe.photo), title: recipe.name, subtitle: '25 min', onTap: open)
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_palette.dart';
import '../01_design_system/app_tokens.dart';

/// A metric with an optional change versus the previous period.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.delta,
    this.higherIsBetter = true,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Fractional change, e.g. 0.12 = +12%. Null hides the delta.
  final double? delta;

  /// Whether an increase is good news (green) or bad news (red) — e.g.
  /// false for "expenses" or "errors".
  final bool higherIsBetter;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = SemanticColors.of(context);
    final d = delta;
    final good = d == null || d == 0 ? null : (d > 0) == higherIsBetter;
    final deltaColor = good == null
        ? scheme.onSurfaceVariant
        : (good ? semantic.success : scheme.error);
    final deltaText = d == null
        ? null
        : '${d > 0 ? '+' : ''}${(d * 100).toStringAsFixed(d.abs() < 0.1 ? 1 : 0)}%';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: Insets.card,
          child: Semantics(
            label: '$label: $value${deltaText == null ? '' : ', $deltaText'}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: scheme.primary),
                      const SizedBox(width: Gap.sm),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: theme.textTheme.headlineMedium),
                ),
                if (deltaText != null || caption != null) ...[
                  const SizedBox(height: Gap.xs),
                  Row(
                    children: [
                      if (deltaText != null) ...[
                        Icon(
                          d! > 0
                              ? Icons.trending_up
                              : (d < 0
                                    ? Icons.trending_down
                                    : Icons.trending_flat),
                          size: 16,
                          color: deltaColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          deltaText,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: deltaColor,
                          ),
                        ),
                        const SizedBox(width: Gap.xs),
                      ],
                      if (caption != null)
                        Expanded(
                          child: Text(
                            caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon, a title, an optional subtitle and a trailing widget (a chevron
/// by default when tappable).
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Tint for the icon badge. Defaults to the primary colour.
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: Insets.card,
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(icon, color: tint),
                ),
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  (onTap == null
                      ? const SizedBox.shrink()
                      : Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
            ],
          ),
        ),
      ),
    );
  }
}

/// A picture on top, title and subtitle below, an optional badge in the
/// corner. A broken or missing image shows an icon placeholder instead of
/// an error box.
class ImageCard extends StatelessWidget {
  const ImageCard({
    super.key,
    required this.title,
    this.image,
    this.subtitle,
    this.badge,
    this.aspectRatio = 16 / 10,
    this.onTap,
  });

  final String title;
  final ImageProvider? image;
  final String? subtitle;

  /// A short label on the image, e.g. "NEW" or "-20%".
  final String? badge;
  final double aspectRatio;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image == null)
                    placeholder
                  else
                    Image(
                      image: image!,
                      fit: BoxFit.cover,
                      semanticLabel: title,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
                  if (badge != null)
                    Positioned(
                      top: Gap.sm,
                      left: Gap.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.md - 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
