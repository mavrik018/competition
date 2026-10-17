// Add / edit form in a bottom sheet, built from field specs (DynamicForm).
// Add a field: add a spec here and read it in `_toItem`.

import 'package:{{app_name}}/toolkit/04_dialogs_and_sheets/bottom_sheets.dart';
import 'package:{{app_name}}/toolkit/05_forms/dynamic_form.dart';
import 'package:flutter/material.dart';

import 'item.dart';

/// Returns the new or edited item, or null if the sheet was dismissed.
Future<Item?> showItemForm(BuildContext context, {Item? existing}) =>
    showAppBottomSheet<Item>(
      context,
      title: existing == null ? 'New item' : 'Edit item',
      builder: (sheetContext) => DynamicForm(
        fields: [
          const TextFieldSpec(
            key: 'title',
            label: 'Title',
            required: true,
            maxLength: 80,
          ),
          const TextFieldSpec(
            key: 'notes',
            label: 'Notes',
            kind: TextKind.multiline,
          ),
          const SliderFieldSpec(
            key: 'importance',
            label: 'Importance',
            min: 1,
            max: 5,
            divisions: 4,
          ),
          DateFieldSpec(
            key: 'due',
            label: 'Due date',
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          ),
        ],
        initialValues: existing == null
            ? const {}
            : {
                'title': existing.title,
                'notes': existing.notes,
                'importance': existing.importance.toDouble(),
                'due': existing.due,
              },
        submitLabel: existing == null ? 'Add' : 'Save',
        onSubmit: (values) =>
            Navigator.pop(sheetContext, _toItem(values, existing)),
      ),
    );

Item _toItem(Map<String, Object?> values, Item? existing) {
  final title = values['title']! as String;
  final notes = values['notes'] as String?;
  final importance = (values['importance'] as num?)?.round() ?? 3;
  final due = values['due'] as DateTime?;
  return existing == null
      ? Item.create(
          title: title,
          notes: notes,
          importance: importance,
          due: due,
        )
      : existing.copyWith(
          title: title,
          notes: notes,
          importance: importance,
          due: due,
          clearDue: due == null,
        );
}
