/// Text inputs beyond a plain `TextField`: a labelled field with required
/// marker and clear button, a password field with show/hide, a one-time-code
/// (PIN/OTP) field, and a tag/chips input.
///
/// Newly written. The source apps used raw `TextFormField`s with a shared
/// decoration (StudyBuddies `SMTextField`), re-implemented the password eye
/// on each auth screen, and had no PIN or tag input.
///
/// ```dart
/// AppTextField(label: 'Title', isRequired: true, controller: title)
/// PasswordField(controller: password, validator: Validators.minLength(8))
/// PinCodeField(length: 6, onCompleted: verify)
/// TagInputField(tags: tags, onChanged: (t) => setState(() => tags = t), suggestions: const ['work', 'home'])
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../01_design_system/app_tokens.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.isRequired = false,
    this.clearable = false,
    this.enabled = true,
    this.obscureText = false,
    this.autofillHints,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? maxLength;

  /// Adds " *" to the label and fails validation when empty (before
  /// [validator] runs).
  final bool isRequired;

  /// Shows a clear button while there is text (ignored when [suffix] set).
  final bool clearable;
  final bool enabled;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  TextEditingController? _own;
  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    if (widget.clearable) _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _own?.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  String? _validate(String? value) {
    if (widget.isRequired && (value == null || value.trim().isEmpty)) {
      return '${widget.label ?? 'This field'} is required';
    }
    return widget.validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final showClear =
        widget.clearable &&
        widget.suffix == null &&
        _controller.text.isNotEmpty;
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: _validate,
      decoration: InputDecoration(
        labelText: widget.label == null
            ? null
            : (widget.isRequired ? '${widget.label} *' : widget.label),
        hintText: widget.hint,
        helperText: widget.helperText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon:
            widget.suffix ??
            (showClear
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.cancel, size: 20),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                    },
                  )
                : null),
      ),
    );
  }
}

/// A password field with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    this.controller,
    this.label = 'Password',
    this.validator,
    this.onSubmitted,
    this.isNewPassword = false,
  });

  final TextEditingController? controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  /// Tells password managers to offer to generate/save a new password.
  final bool isNewPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      obscureText: _obscure,
      validator: widget.validator,
      onSubmitted: widget.onSubmitted,
      keyboardType: TextInputType.visiblePassword,
      textCapitalization: TextCapitalization.none,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      suffix: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

/// A one-time code entry shown as separate boxes.
///
/// Implemented as one hidden `TextField` behind the boxes rather than one
/// field per box: paste, backspace across boxes, SMS autofill
/// (`AutofillHints.oneTimeCode`) and screen readers all work because there
/// is a single real input.
class PinCodeField extends StatefulWidget {
  const PinCodeField({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.obscure = false,
    this.hasError = false,
    this.autofocus = true,
    this.controller,
  });

  final int length;
  final ValueChanged<String>? onChanged;

  /// Called once all [length] digits are entered.
  final ValueChanged<String>? onCompleted;
  final bool obscure;

  /// Outlines every box in the error colour.
  final bool hasError;
  final bool autofocus;
  final TextEditingController? controller;

  @override
  State<PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<PinCodeField> {
  TextEditingController? _own;
  final _focus = FocusNode();

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _controller.text;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The real input: invisible but focusable and semantic.
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              showCursor: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: '', filled: false),
              onChanged: _changed,
            ),
          ),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.length; i++)
                  AnimatedContainer(
                    duration: Motion.short,
                    width: 44,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(
                        width: 1.5,
                        color: widget.hasError
                            ? scheme.error
                            : (i == text.length && _focus.hasFocus
                                  ? scheme.primary
                                  : scheme.outlineVariant),
                      ),
                    ),
                    child: Text(
                      i < text.length ? (widget.obscure ? '•' : text[i]) : '',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Free-form tags shown as chips: type and press Enter (or a comma) to add,
/// tap × to remove, backspace in an empty field removes the last tag.
class TagInputField extends StatefulWidget {
  const TagInputField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.label = 'Tags',
    this.suggestions = const [],
    this.maxTags,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String label;

  /// Shown as tappable chips below, excluding tags already added.
  final List<String> suggestions;
  final int? maxTags;

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final _controller = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Backspace in an empty field removes the last tag.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty &&
        widget.tags.isNotEmpty) {
      _remove(widget.tags.last);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _full =>
      widget.maxTags != null && widget.tags.length >= widget.maxTags!;

  void _add(String raw) {
    final tag = raw.trim().replaceAll(',', '');
    _controller.clear();
    if (tag.isEmpty || _full) return;
    final exists = widget.tags.any((t) => t.toLowerCase() == tag.toLowerCase());
    if (!exists) widget.onChanged([...widget.tags, tag]);
  }

  void _remove(String tag) => widget.onChanged([...widget.tags]..remove(tag));

  @override
  Widget build(BuildContext context) {
    final remaining = widget.suggestions
        .where(
          (s) => !widget.tags.any((t) => t.toLowerCase() == s.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final tag in widget.tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => _remove(tag),
                  deleteButtonTooltipMessage: 'Remove $tag',
                ),
            ],
          ),
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _controller,
          focusNode: _focus,
          enabled: !_full,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: _full ? 'Maximum reached' : 'Type and press Enter',
          ),
          onChanged: (value) {
            if (value.endsWith(',')) _add(value);
          },
          // Keep focus after Enter so several tags can be typed in a row.
          onSubmitted: (value) {
            _add(value);
            _focus.requestFocus();
          },
        ),
        if (remaining.isNotEmpty && !_full) ...[
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            children: [
              for (final suggestion in remaining)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(suggestion),
                  onPressed: () => _add(suggestion),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
