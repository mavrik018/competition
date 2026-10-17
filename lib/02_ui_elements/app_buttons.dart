/// One button API for every emphasis level — filled, tonal, outlined, text
/// and destructive — in three sizes, with icons and a loading state; plus
/// branded "Continue with …" sign-in buttons.
///
/// Newly written to fill a gap: the toolkit had only the full-width
/// `PrimaryButton`, and the source apps styled secondary buttons ad hoc on
/// every screen. Built on Material 3 buttons, so they follow the theme.
///
/// ```dart
/// AppButton(label: 'Save', onPressed: save)                                   // filled
/// AppButton(label: 'Cancel', variant: ButtonVariant.text, onPressed: close)
/// AppButton(label: 'Filters', icon: Icons.tune, variant: ButtonVariant.tonal, size: ButtonSize.small, onPressed: openFilters)
/// AppButton(label: 'Delete', variant: ButtonVariant.destructive, isLoading: deleting, onPressed: delete)
/// SocialSignInButton(provider: SocialProvider.apple, onPressed: auth.signInWithApple)
/// ```
library;

import 'package:flutter/material.dart';

enum ButtonVariant { filled, tonal, outlined, text, destructive }

enum ButtonSize {
  small(36, 13, 16),
  medium(44, 15, 18),
  large(52, 16, 20);

  const ButtonSize(this.height, this.fontSize, this.iconSize);
  final double height;
  final double fontSize;
  final double iconSize;
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.filled,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;

  /// Spinner instead of the icon, taps ignored, colours kept.
  final bool isLoading;

  /// Stretch to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(size.height * 1.6, size.height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: size.height * 0.4),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: size.fontSize, fontWeight: FontWeight.w600),
      ),
      backgroundColor: variant == ButtonVariant.destructive
          ? WidgetStatePropertyAll(scheme.error)
          : null,
      foregroundColor: variant == ButtonVariant.destructive
          ? WidgetStatePropertyAll(scheme.onError)
          : null,
    );

    final Widget? leading = isLoading
        ? SizedBox.square(
            dimension: size.iconSize - 2,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon == null ? null : Icon(icon, size: size.iconSize));
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    // While loading the button keeps an onPressed (so it keeps its colours)
    // but ignores pointer input, so a request cannot be submitted twice.
    final VoidCallback? handler = onPressed == null
        ? null
        : (isLoading ? () {} : onPressed);

    final Widget button = switch (variant) {
      ButtonVariant.filled || ButtonVariant.destructive =>
        leading == null
            ? FilledButton(onPressed: handler, style: style, child: text)
            : FilledButton.icon(
                onPressed: handler,
                style: style,
                icon: leading,
                label: text,
              ),
      ButtonVariant.tonal =>
        leading == null
            ? FilledButton.tonal(onPressed: handler, style: style, child: text)
            : FilledButton.tonalIcon(
                onPressed: handler,
                style: style,
                icon: leading,
                label: text,
              ),
      ButtonVariant.outlined =>
        leading == null
            ? OutlinedButton(onPressed: handler, style: style, child: text)
            : OutlinedButton.icon(
                onPressed: handler,
                style: style,
                icon: leading,
                label: text,
              ),
      ButtonVariant.text =>
        leading == null
            ? TextButton(onPressed: handler, style: style, child: text)
            : TextButton.icon(
                onPressed: handler,
                style: style,
                icon: leading,
                label: text,
              ),
    };

    return Semantics(
      label: isLoading ? '$label, loading' : null,
      child: IgnorePointer(
        ignoring: isLoading,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}

enum SocialProvider {
  apple('Apple'),
  google('Google'),
  email('email'),
  phone('phone');

  const SocialProvider(this.displayName);
  final String displayName;
}

/// "Continue with Apple / Google / email / phone" in a consistent outlined
/// style. Apple's own guidelines prefer a black button on light themes, so
/// the Apple variant is filled with the on-surface colour.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.isLoading = false,
  });

  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = 'Continue with ${provider.displayName}';
    final Widget icon = switch (provider) {
      SocialProvider.apple => const Icon(Icons.apple, size: 22),
      // Material has no Google glyph and the logo has usage rules; a
      // neutral "G" mark avoids shipping a trademarked asset.
      SocialProvider.google => const Text(
        'G',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      SocialProvider.email => const Icon(Icons.mail_outline, size: 20),
      SocialProvider.phone => const Icon(Icons.phone_iphone, size: 20),
    };
    final Widget leading = isLoading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon;
    final VoidCallback? handler = onPressed == null
        ? null
        : (isLoading ? () {} : onPressed);
    final style = provider == SocialProvider.apple
        ? FilledButton.styleFrom(
            backgroundColor: scheme.onSurface,
            foregroundColor: scheme.surface,
            minimumSize: const Size(double.infinity, 52),
          )
        : OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          );

    return Semantics(
      label: isLoading ? '$label, loading' : null,
      child: IgnorePointer(
        ignoring: isLoading,
        child: provider == SocialProvider.apple
            ? FilledButton.icon(
                onPressed: handler,
                style: style,
                icon: leading,
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: handler,
                style: style,
                icon: leading,
                label: Text(label),
              ),
      ),
    );
  }
}
