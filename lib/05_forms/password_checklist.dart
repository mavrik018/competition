import 'package:flutter/material.dart';

import '../01_design_system/app_palette.dart';
import '../01_design_system/app_tokens.dart';

/// One password requirement: a label and a test.
class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String password) test;

  /// The rules StudyBuddies enforced at sign-up.
  static final defaults = <PasswordRule>[
    PasswordRule('At least 8 characters', (p) => p.length >= 8),
    PasswordRule(
      'An uppercase letter (A-Z)',
      (p) => p.contains(RegExp('[A-Z]')),
    ),
    PasswordRule(
      'A lowercase letter (a-z)',
      (p) => p.contains(RegExp('[a-z]')),
    ),
    PasswordRule(
      'A number or symbol',
      (p) => p.contains(RegExp(r'[0-9!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/~`;]')),
    ),
  ];
}

/// True when [password] satisfies every rule.
bool passwordMeetsAll(String password, [List<PasswordRule>? rules]) =>
    (rules ?? PasswordRule.defaults).every((rule) => rule.test(password));

/// A live checklist under a password field: each rule ticks green as soon as
/// the typed password satisfies it.
///
/// Source: StudyBuddies `password_requirements_checklist.dart`. The rules
/// were hard-coded there; here they are data, so an app can ask for
/// different ones without touching the widget.
///
/// ```dart
/// TextFormField(controller: password, obscureText: true, onChanged: (_) => setState(() {})),
/// PasswordChecklist(password: password.text),
/// FilledButton(onPressed: passwordMeetsAll(password.text) ? submit : null, …)
/// ```
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    super.key,
    required this.password,
    this.rules,
    this.title = 'Password must contain:',
  });

  final String password;

  /// Defaults to [PasswordRule.defaults].
  final List<PasswordRule>? rules;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final success = SemanticColors.of(context).success;

    return Container(
      margin: const EdgeInsets.only(top: Gap.sm),
      padding: const EdgeInsets.all(Gap.md - 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md - 2),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
          for (final rule in rules ?? PasswordRule.defaults)
            _RuleRow(
              label: rule.label,
              met: rule.test(password),
              metColor: success,
            ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.label,
    required this.met,
    required this.metColor,
  });

  final String label;
  final bool met;
  final Color metColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: '$label, ${met ? 'met' : 'not met'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: Motion.short,
              child: Icon(
                met
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(met),
                size: 16,
                color: met ? metColor : muted.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: met ? theme.colorScheme.onSurface : muted,
                  fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
