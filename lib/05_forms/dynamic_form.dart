/// A form generated from a list of field specs — in code or from JSON —
/// that validates and returns a `Map<String, Object?>` of values.
///
/// Newly written for "unknown problem" situations: a registration form, a
/// survey, an inspection checklist or a CRUD editor can be described as data
/// (even downloaded from a backend) instead of hand-building every screen.
///
/// ```dart
/// DynamicForm(
///   fields: [
///     TextFieldSpec(key: 'name', label: 'Name', required: true),
///     TextFieldSpec(key: 'email', label: 'Email', kind: TextKind.email),
///     NumberFieldSpec(key: 'age', label: 'Age', min: 0, max: 120),
///     ChoiceFieldSpec(key: 'role', label: 'Role', options: [FieldOption('student', 'Student'), FieldOption('staff', 'Staff')]),
///     ChoiceFieldSpec(key: 'interests', label: 'Interests', multiple: true, options: [...]),
///     DateFieldSpec(key: 'start', label: 'Start date'),
///     SwitchFieldSpec(key: 'newsletter', label: 'Send me updates'),
///     SliderFieldSpec(key: 'rating', label: 'Rating', min: 1, max: 5, divisions: 4),
///   ],
///   initialValues: existing?.toJson() ?? const {},
///   submitLabel: 'Save',
///   onSubmit: (values) => repo.save(Person.fromJson(values)),
/// )
///
/// // Or from JSON (e.g. a Supabase `forms` table):
/// final fields = [for (final f in json['fields']) FieldSpec.fromJson(f)];
/// ```
///
/// Value types: text → `String` (trimmed), number → `num`, single choice →
/// `String`, multiple choice → `List<String>`, switch → `bool`, date →
/// `DateTime`, slider → `double`. Empty optional fields are `null`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import 'calendar_grid.dart';
import 'validators.dart';

enum TextKind { text, multiline, email, phone, url, password }

sealed class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.label,
    this.required = false,
    this.helper,
  });

  /// Map key in the submitted values.
  final String key;
  final String label;
  final bool required;
  final String? helper;

  /// Builds a spec from `{"type": "text"|"number"|"choice"|"switch"|"date"|"slider", ...}`.
  static FieldSpec fromJson(Map<String, Object?> json) {
    final key = json['key'] as String;
    final label = json['label'] as String? ?? key;
    final required = json['required'] == true;
    final helper = json['helper'] as String?;
    return switch (json['type']) {
      'text' => TextFieldSpec(
        key: key,
        label: label,
        required: required,
        helper: helper,
        hint: json['hint'] as String?,
        kind: TextKind.values.firstWhere(
          (k) => k.name == (json['kind'] ?? 'text'),
          orElse: () => TextKind.text,
        ),
        maxLength: json['maxLength'] as int?,
      ),
      'number' => NumberFieldSpec(
        key: key,
        label: label,
        required: required,
        helper: helper,
        min: json['min'] as num?,
        max: json['max'] as num?,
        decimal: json['decimal'] != false,
        suffix: json['suffix'] as String?,
      ),
      'choice' => ChoiceFieldSpec(
        key: key,
        label: label,
        required: required,
        helper: helper,
        multiple: json['multiple'] == true,
        options: [
          for (final o in (json['options'] as List? ?? const []))
            o is Map
                ? FieldOption('${o['value']}', '${o['label'] ?? o['value']}')
                : FieldOption('$o', '$o'),
        ],
      ),
      'switch' => SwitchFieldSpec(key: key, label: label, helper: helper),
      'date' => DateFieldSpec(
        key: key,
        label: label,
        required: required,
        helper: helper,
      ),
      'slider' => SliderFieldSpec(
        key: key,
        label: label,
        helper: helper,
        min: (json['min'] as num? ?? 0).toDouble(),
        max: (json['max'] as num? ?? 10).toDouble(),
        divisions: json['divisions'] as int?,
      ),
      final type => throw FormatException(
        'Unknown field type "$type" for "$key"',
      ),
    };
  }
}

class TextFieldSpec extends FieldSpec {
  const TextFieldSpec({
    required super.key,
    required super.label,
    super.required,
    super.helper,
    this.hint,
    this.kind = TextKind.text,
    this.maxLength,
    this.validators = const [],
  });

  final String? hint;
  final TextKind kind;
  final int? maxLength;

  /// Extra checks, run after the built-in ones for [kind].
  final List<StringValidator> validators;
}

class NumberFieldSpec extends FieldSpec {
  const NumberFieldSpec({
    required super.key,
    required super.label,
    super.required,
    super.helper,
    this.min,
    this.max,
    this.decimal = true,
    this.suffix,
  });

  final num? min;
  final num? max;

  /// False allows whole numbers only.
  final bool decimal;
  final String? suffix;
}

class FieldOption {
  const FieldOption(this.value, this.label);
  final String value;
  final String label;
}

/// A dropdown (single) or a set of filter chips (multiple).
class ChoiceFieldSpec extends FieldSpec {
  const ChoiceFieldSpec({
    required super.key,
    required super.label,
    required this.options,
    super.required,
    super.helper,
    this.multiple = false,
  });

  final List<FieldOption> options;
  final bool multiple;
}

class SwitchFieldSpec extends FieldSpec {
  const SwitchFieldSpec({
    required super.key,
    required super.label,
    super.helper,
  });
}

class DateFieldSpec extends FieldSpec {
  const DateFieldSpec({
    required super.key,
    required super.label,
    super.required,
    super.helper,
    this.firstDate,
    this.lastDate,
  });

  final DateTime? firstDate;
  final DateTime? lastDate;
}

class SliderFieldSpec extends FieldSpec {
  const SliderFieldSpec({
    required super.key,
    required super.label,
    super.helper,
    this.min = 0,
    this.max = 10,
    this.divisions,
  });

  final double min;
  final double max;
  final int? divisions;
}

class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.fields,
    required this.onSubmit,
    this.initialValues = const {},
    this.submitLabel = 'Submit',
    this.showSubmitButton = true,
    this.onChanged,
  });

  final List<FieldSpec> fields;

  /// Receives the validated values. If it returns a Future, the button shows
  /// a spinner until it completes.
  final FutureOr<void> Function(Map<String, Object?> values) onSubmit;
  final Map<String, Object?> initialValues;
  final String submitLabel;

  /// Hide the built-in button and call `DynamicFormState.submit()` via a
  /// GlobalKey instead (e.g. from an app-bar "Save" action).
  final bool showSubmitButton;
  final ValueChanged<Map<String, Object?>>? onChanged;

  @override
  State<DynamicForm> createState() => DynamicFormState();
}

class DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  late final Map<String, Object?> _values = {...widget.initialValues};
  bool _submitting = false;

  /// Current values (unvalidated).
  Map<String, Object?> get values => Map.unmodifiable(_collect());

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      // Controls that always show a value submit that value, not null.
      if (field is SwitchFieldSpec) _values[field.key] ??= false;
      if (field is SliderFieldSpec) _values[field.key] ??= field.min;
      if (field is TextFieldSpec || field is NumberFieldSpec) {
        final initial = _values[field.key];
        _controllers[field.key] = TextEditingController(
          text: initial == null ? '' : '$initial',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _collect() {
    final out = <String, Object?>{..._values};
    for (final field in widget.fields) {
      final text = _controllers[field.key]?.text.trim();
      if (field is TextFieldSpec) {
        out[field.key] = (text == null || text.isEmpty) ? null : text;
      }
      if (field is NumberFieldSpec) {
        out[field.key] = (text == null || text.isEmpty)
            ? null
            : num.tryParse(text.replaceAll(',', '.'));
      }
    }
    return out;
  }

  void _set(String key, Object? value) {
    setState(() => _values[key] = value);
    widget.onChanged?.call(_collect());
  }

  /// Validates and, if valid, calls `onSubmit`. Returns whether it was valid.
  Future<bool> submit() async {
    if (_submitting) return false;
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_collect());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in widget.fields) ...[
            _buildField(context, field),
            const SizedBox(height: Gap.md),
          ],
          if (widget.showSubmitButton)
            FilledButton(
              onPressed: _submitting ? null : submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.submitLabel),
            ),
        ],
      ),
    );
  }

  String _label(FieldSpec field) =>
      field.required ? '${field.label} *' : field.label;

  String? _requiredCheck(FieldSpec field, Object? value) {
    if (!field.required) return null;
    final empty =
        value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is List && value.isEmpty);
    return empty ? '${field.label} is required' : null;
  }

  Widget _buildField(BuildContext context, FieldSpec field) {
    switch (field) {
      case TextFieldSpec():
        final kindValidator = switch (field.kind) {
          TextKind.email => Validators.email(),
          TextKind.phone => Validators.phone(),
          TextKind.url => Validators.url(),
          _ => null,
        };
        return TextFormField(
          controller: _controllers[field.key],
          obscureText: field.kind == TextKind.password,
          maxLines: field.kind == TextKind.multiline ? 4 : 1,
          maxLength: field.maxLength,
          keyboardType: switch (field.kind) {
            TextKind.email => TextInputType.emailAddress,
            TextKind.phone => TextInputType.phone,
            TextKind.url => TextInputType.url,
            TextKind.multiline => TextInputType.multiline,
            _ => TextInputType.text,
          },
          decoration: InputDecoration(
            labelText: _label(field),
            hintText: field.hint,
            helperText: field.helper,
          ),
          onChanged: (_) => widget.onChanged?.call(_collect()),
          validator: Validators.compose([
            (v) => _requiredCheck(field, v),
            ?kindValidator, // `?x` adds x to the list only when it is non-null
            ...field.validators,
          ]),
        );
      case NumberFieldSpec():
        return TextFormField(
          controller: _controllers[field.key],
          keyboardType: TextInputType.numberWithOptions(
            decimal: field.decimal,
            signed: (field.min ?? 0) < 0,
          ),
          decoration: InputDecoration(
            labelText: _label(field),
            helperText: field.helper,
            suffixText: field.suffix,
          ),
          onChanged: (_) => widget.onChanged?.call(_collect()),
          validator: Validators.compose([
            (v) => _requiredCheck(field, v),
            field.decimal
                ? Validators.number(min: field.min, max: field.max)
                : Validators.integer(
                    min: field.min?.toInt(),
                    max: field.max?.toInt(),
                  ),
          ]),
        );
      case ChoiceFieldSpec(multiple: false):
        return DropdownButtonFormField<String>(
          initialValue: field.options.any((o) => o.value == _values[field.key])
              ? _values[field.key] as String
              : null,
          decoration: InputDecoration(
            labelText: _label(field),
            helperText: field.helper,
          ),
          items: [
            for (final o in field.options)
              DropdownMenuItem(value: o.value, child: Text(o.label)),
          ],
          onChanged: (v) => _set(field.key, v),
          validator: (v) => _requiredCheck(field, v),
        );
      case ChoiceFieldSpec(multiple: true):
        final selected = ((_values[field.key] as List?) ?? const [])
            .cast<String>();
        return FormField<List<String>>(
          initialValue: selected,
          validator: (_) => _requiredCheck(field, _values[field.key]),
          builder: (state) => InputDecorator(
            decoration: InputDecoration(
              labelText: _label(field),
              helperText: field.helper,
              errorText: state.errorText,
              border: InputBorder.none,
              filled: false,
            ),
            child: Wrap(
              spacing: Gap.sm,
              children: [
                for (final o in field.options)
                  FilterChip(
                    label: Text(o.label),
                    selected: selected.contains(o.value),
                    onSelected: (on) => _set(
                      field.key,
                      on
                          ? [...selected, o.value]
                          : (List<String>.of(selected)..remove(o.value)),
                    ),
                  ),
              ],
            ),
          ),
        );
      case SwitchFieldSpec():
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.helper == null ? null : Text(field.helper!),
          value: _values[field.key] == true,
          onChanged: (v) => _set(field.key, v),
        );
      case DateFieldSpec():
        final value = _values[field.key];
        final date = value is DateTime
            ? value
            : (value is String ? DateTime.tryParse(value) : null);
        return FormField<DateTime>(
          validator: (_) => _requiredCheck(field, _values[field.key]),
          builder: (state) => InkWell(
            onTap: () async {
              final picked = await showDatePickerSheet(
                context,
                initialDate: date ?? DateTime.now(),
                firstDate: field.firstDate,
                lastDate: field.lastDate,
                title: field.label,
              );
              if (picked != null) _set(field.key, picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: _label(field),
                helperText: field.helper,
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                date == null
                    ? ''
                    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              ),
            ),
          ),
        );
      case SliderFieldSpec():
        final value = ((_values[field.key] as num?) ?? field.min)
            .toDouble()
            .clamp(field.min, field.max);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${field.label}: ${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)}',
            ),
            Slider(
              value: value,
              min: field.min,
              max: field.max,
              divisions: field.divisions,
              label: '$value',
              onChanged: (v) => _set(field.key, v),
            ),
          ],
        );
    }
  }
}
