/// Small composable validators for `TextFormField.validator`.
///
/// Newly written. The source apps validated inline with one-off lambdas
/// (`(v) => v == null || v.isEmpty ? 'Required' : null`) repeated across the
/// sign-in, sign-up and composer screens, with slightly different rules and
/// wording each time. These return `null` when valid and a message when not,
/// which is exactly what [FormField] expects.
///
/// ```dart
/// TextFormField(
///   validator: Validators.compose([
///     Validators.required('Enter your email'),
///     Validators.email(),
///   ]),
/// )
/// ```
library;

typedef StringValidator = String? Function(String? value);

abstract final class Validators {
  /// Fails on null, empty or whitespace-only input.
  static StringValidator required([
    String message = 'This field is required',
  ]) =>
      (value) => (value == null || value.trim().isEmpty) ? message : null;

  /// A pragmatic email check: something@something.tld, no spaces. Empty input
  /// passes — combine with [required] when the field is mandatory.
  static StringValidator email([
    String message = 'Enter a valid email address',
  ]) {
    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    return (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return null;
      return pattern.hasMatch(text) ? null : message;
    };
  }

  static StringValidator minLength(int min, [String? message]) =>
      (value) => (value ?? '').length < min
      ? (message ?? 'Must be at least $min characters')
      : null;

  static StringValidator maxLength(int max, [String? message]) =>
      (value) => (value ?? '').length > max
      ? (message ?? 'Must be at most $max characters')
      : null;

  /// For "confirm password": compares against another field's current text.
  static StringValidator matches(
    String Function() other, [
    String message = "Doesn't match",
  ]) =>
      (value) => value == other() ? null : message;

  /// Whole numbers within an optional range. Empty input passes.
  static StringValidator integer({
    int? min,
    int? max,
    String? message,
  }) => (value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null) return message ?? 'Enter a whole number';
    if (min != null && number < min) return message ?? 'Must be at least $min';
    if (max != null && number > max) return message ?? 'Must be at most $max';
    return null;
  };

  /// Decimal numbers (`3`, `2.5`, `-1`, `1,5` with a comma) within an
  /// optional range. Empty input passes.
  static StringValidator number({
    num? min,
    num? max,
    String? message,
  }) => (value) {
    final text = value?.trim().replaceAll(',', '.') ?? '';
    if (text.isEmpty) return null;
    final number = num.tryParse(text);
    if (number == null) return message ?? 'Enter a number';
    if (min != null && number < min) return message ?? 'Must be at least $min';
    if (max != null && number > max) return message ?? 'Must be at most $max';
    return null;
  };

  /// A phone number: optional leading +, then 7–15 digits; spaces, dashes,
  /// dots and brackets are allowed as separators. Empty input passes.
  static StringValidator phone([
    String message = 'Enter a valid phone number',
  ]) => (value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^\+?[\d\s\-().]+$').hasMatch(text)) return message;
    final digits = text.replaceAll(RegExp(r'\D'), '').length;
    return digits >= 7 && digits <= 15 ? null : message;
  };

  /// An http(s) URL with a host. Empty input passes.
  static StringValidator url([String message = 'Enter a valid web address']) =>
      (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
        final ok =
            uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.contains('.');
        return ok ? null : message;
      };

  /// Matches a regular expression (whole input). Empty input passes.
  static StringValidator pattern(RegExp regex, String message) => (value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final match = regex.firstMatch(text);
    return match != null && match.start == 0 && match.end == text.length
        ? null
        : message;
  };

  /// Runs [validators] in order and returns the first failure.
  static StringValidator compose(List<StringValidator> validators) => (value) {
    for (final validate in validators) {
      final error = validate(value);
      if (error != null) return error;
    }
    return null;
  };
}
