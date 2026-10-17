import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A tappable link inside a [ConsentCheckbox] sentence.
class ConsentLink {
  const ConsentLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

/// "I agree to the Terms of Use and Privacy Policy." — a rounded checkbox
/// whose sentence contains tappable document links.
///
/// Source: StudyBuddies `legal_consent_checkbox.dart`, which opened its own
/// legal sheets. Here the links are passed in, so any number of documents
/// can be linked and they can open anything (a sheet, a web page).
///
/// ```dart
/// ConsentCheckbox(
///   value: agreed,
///   onChanged: busy ? null : (v) => setState(() => agreed = v),
///   links: [
///     ConsentLink('Terms of Use', () => launchUrl(termsUrl)),
///     ConsentLink('Privacy Policy', () => launchUrl(privacyUrl)),
///   ],
/// )
/// ```
class ConsentCheckbox extends StatefulWidget {
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.links,
    this.prefix = 'I agree to the ',
  });

  final bool value;

  /// Null disables the row — e.g. while a sign-up request is running.
  final ValueChanged<bool>? onChanged;
  final List<ConsentLink> links;
  final String prefix;

  @override
  State<ConsentCheckbox> createState() => _ConsentCheckboxState();
}

class _ConsentCheckboxState extends State<ConsentCheckbox> {
  // Gesture recognizers must be disposed, so they live in State.
  List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
  }

  @override
  void didUpdateWidget(ConsentCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.links != widget.links) {
      _disposeRecognizers();
      _buildRecognizers();
    }
  }

  void _buildRecognizers() {
    _recognizers = [
      for (final link in widget.links)
        TapGestureRecognizer()..onTap = link.onTap,
    ];
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _toggle() {
    final onChanged = widget.onChanged;
    if (onChanged == null) return;
    HapticFeedback.selectionClick();
    onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.onChanged != null;
    final accent = enabled
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.38);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: enabled ? scheme.onSurfaceVariant : accent,
      height: 1.45,
    );
    final linkStyle = base?.copyWith(
      color: accent,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: accent,
    );

    final spans = <InlineSpan>[TextSpan(text: widget.prefix)];
    for (var i = 0; i < widget.links.length; i++) {
      if (i > 0) {
        spans.add(
          TextSpan(text: i == widget.links.length - 1 ? ' and ' : ', '),
        );
      }
      spans.add(
        TextSpan(
          text: widget.links[i].label,
          style: linkStyle,
          recognizer: _recognizers[i],
        ),
      );
    }
    spans.add(const TextSpan(text: '.'));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The box carries the checkbox semantics; the sentence stays a
          // separate node so screen readers can still activate each link.
          Semantics(
            checked: widget.value,
            enabled: enabled,
            label: widget.prefix.trim(),
            onTap: enabled ? _toggle : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(top: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: widget.value ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.value ? accent : scheme.outline,
                  width: 1.8,
                ),
              ),
              child: widget.value
                  ? const Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(TextSpan(style: base, children: spans)),
          ),
        ],
      ),
    );
  }
}
