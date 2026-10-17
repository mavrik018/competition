/// A profile screen: avatar (photo or initials), name, subtitle, edit
/// button, a row of stats, then your own sections.
///
/// Source: StudyBuddies `profile_screen.dart` (1,057 lines) and Cookly's
/// profile with `KitchenStatsCard`, reduced to the reusable frame. The
/// initials fallback is from StudyBuddies `user_display.dart`.
///
/// ```dart
/// ProfileTemplate(
///   name: user.name,
///   subtitle: user.email,
///   image: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
///   stats: const [ProfileStat('Notes', '128'), ProfileStat('Streak', '12 days')],
///   onEdit: openEditProfile,
///   sections: [
///     FormSection(header: 'Account', children: [...]),
///   ],
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

class ProfileStat {
  const ProfileStat(this.label, this.value);
  final String label;
  final String value;
}

/// "Ana Lima" → "AL", "sam" → "S", "" → "?". Uses the first letters of the
/// first and last words.
String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first.characters.first;
  final last = words.length > 1 ? words.last.characters.first : '';
  return (first + last).toUpperCase();
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.image,
    this.radius = 40,
  });

  final String name;
  final ImageProvider? image;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$name profile picture',
      image: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundImage: image,
        // Initials stay visible underneath while the image loads or if it fails.
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontSize: radius * 0.7,
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ProfileTemplate extends StatelessWidget {
  const ProfileTemplate({
    super.key,
    required this.name,
    this.subtitle,
    this.image,
    this.stats = const [],
    this.sections = const [],
    this.onEdit,
    this.title = 'Profile',
    this.actions = const [],
  });

  final String name;
  final String? subtitle;
  final ImageProvider? image;
  final List<ProfileStat> stats;
  final List<Widget> sections;
  final VoidCallback? onEdit;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Gap.gutter,
          Gap.md,
          Gap.gutter,
          Gap.xl,
        ),
        children: [
          Center(
            child: ProfileAvatar(name: name, image: image, radius: 44),
          ),
          const SizedBox(height: Gap.md),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (onEdit != null) ...[
            const SizedBox(height: Gap.md),
            Center(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit profile'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
            ),
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0)
                        const SizedBox(height: 32, child: VerticalDivider()),
                      Expanded(
                        child: Semantics(
                          label: '${stats[i].label}: ${stats[i].value}',
                          excludeSemantics: true,
                          child: Column(
                            children: [
                              Text(
                                stats[i].value,
                                style: theme.textTheme.titleLarge,
                              ),
                              Text(
                                stats[i].label,
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          for (final section in sections) ...[
            const SizedBox(height: Gap.lg),
            section,
          ],
        ],
      ),
    );
  }
}
