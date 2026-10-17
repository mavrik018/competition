/// A [TextEditingController] that styles inline Markdown as you type: the
/// text between `**` turns bold, between `*` italic, between `~~` struck
/// through, between backticks monospace — while the markers themselves stay
/// visible but faded, so the raw text is still editable.
///
/// Source: TaskFlow `core/utils/rich_text_parser.dart`
/// (`RichTextEditingController`). Its own regex was replaced by the shared
/// `parseInline` from `11_utilities/markdown_parser.dart`, so what you see
/// while editing matches what `MarkdownView` renders afterwards.
///
/// ```dart
/// final controller = MarkdownEditingController(text: note.body);
/// TextField(controller: controller, maxLines: null);
/// ```
library;

import 'package:flutter/material.dart';

import '../11_utilities/markdown_parser.dart';

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    // While an IME is composing (e.g. CJK input), keep the default
    // underline behaviour — restyling mid-composition confuses the IME.
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final faded = base.copyWith(
      color: (base.color ?? Theme.of(context).colorScheme.onSurface).withValues(
        alpha: 0.35,
      ),
      fontWeight: FontWeight.normal,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
    );

    final spans = <TextSpan>[];
    for (final span in parseInline(text)) {
      final (marker, styled) = switch (span.style) {
        InlineStyle.plain => ('', base),
        InlineStyle.bold => ('**', base.copyWith(fontWeight: FontWeight.w700)),
        InlineStyle.italic => ('*', base.copyWith(fontStyle: FontStyle.italic)),
        InlineStyle.strikethrough => (
          '~~',
          base.copyWith(decoration: TextDecoration.lineThrough),
        ),
        InlineStyle.code => ('`', base.copyWith(fontFamily: 'monospace')),
      };
      // Markers are re-emitted so the text length (and therefore every
      // cursor position) is exactly what the user typed.
      if (marker.isNotEmpty) spans.add(TextSpan(text: marker, style: faded));
      spans.add(TextSpan(text: span.text, style: styled));
      if (marker.isNotEmpty) spans.add(TextSpan(text: marker, style: faded));
    }
    return TextSpan(style: base, children: spans);
  }
}
