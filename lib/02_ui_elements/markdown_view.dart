/// Renders Markdown — typically an AI response or a note — with the app's
/// theme: headings, bullet and numbered lists, quotes, fenced code, tables,
/// and inline bold / italic / code / strikethrough.
///
/// Source: StudyBuddies `notes/presentation/widgets/markdown_body_view.dart`
/// (hand-rolled renderer instead of `flutter_markdown`, because the AI
/// writes a small known subset) on top of the shared parser in
/// `11_utilities/markdown_parser.dart`. Anything outside the subset (links,
/// images, HTML) shows as plain text rather than breaking.
///
/// ```dart
/// SingleChildScrollView(
///   padding: const EdgeInsets.all(16),
///   child: MarkdownView(data: response.text, selectable: true),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../11_utilities/markdown_parser.dart';

class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.data, this.selectable = false});

  final String data;

  /// Lets the user select and copy text.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdown(data);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final block in blocks) _block(context, block)],
    );
    return selectable ? SelectionArea(child: column) : column;
  }

  Widget _block(BuildContext context, MarkdownBlock block) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final body = text.bodyLarge!;

    switch (block) {
      case MarkdownBlank():
        return const SizedBox(height: Gap.sm);
      case MarkdownHeading(:final level, text: final content):
        final style = switch (level) {
          1 => text.headlineMedium,
          2 => text.titleLarge,
          3 => text.titleMedium,
          _ => text.titleSmall,
        }!;
        return Padding(
          padding: EdgeInsets.only(
            top: level <= 2 ? Gap.md : Gap.sm,
            bottom: Gap.xs,
          ),
          child: Semantics(
            header: true,
            child: Text.rich(
              TextSpan(children: markdownSpans(content, style, scheme)),
            ),
          ),
        );
      case MarkdownBullet(text: final content, :final indent):
        return _listItem(context, '•', content, indent);
      case MarkdownNumbered(:final number, text: final content, :final indent):
        return _listItem(context, '$number.', content, indent);
      case MarkdownQuote(text: final content):
        return Container(
          margin: const EdgeInsets.symmetric(vertical: Gap.xs),
          padding: const EdgeInsets.only(left: Gap.md - 4),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: scheme.primary, width: 3)),
          ),
          child: Text.rich(
            TextSpan(
              children: markdownSpans(
                content,
                body.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                scheme,
              ),
            ),
          ),
        );
      case MarkdownCode(:final code):
        return Container(
          margin: const EdgeInsets.symmetric(vertical: Gap.sm),
          padding: const EdgeInsets.all(Gap.md - 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          // Scroll sideways rather than wrap: wrapping breaks code and
          // box-drawing diagrams.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              style: text.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        );
      case MarkdownTable(:final rows, :final hasHeader):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: scheme.outlineVariant),
              children: [
                for (var r = 0; r < rows.length; r++)
                  TableRow(
                    decoration: hasHeader && r == 0
                        ? BoxDecoration(color: scheme.surfaceContainerHighest)
                        : null,
                    children: [
                      for (final cell in rows[r])
                        Padding(
                          padding: const EdgeInsets.all(Gap.sm),
                          child: Text.rich(
                            TextSpan(
                              children: markdownSpans(
                                cell,
                                hasHeader && r == 0
                                    ? text.bodyMedium!.copyWith(
                                        fontWeight: FontWeight.w700,
                                      )
                                    : text.bodyMedium!,
                                scheme,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      case MarkdownParagraph(text: final content):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.xxs),
          child: Text.rich(
            TextSpan(children: markdownSpans(content, body, scheme)),
          ),
        );
    }
  }

  Widget _listItem(
    BuildContext context,
    String marker,
    String content,
    int indent,
  ) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge!;
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.xs + indent * Gap.md,
        top: Gap.xxs,
        bottom: Gap.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              marker,
              style: body.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: markdownSpans(content, body, theme.colorScheme),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline Markdown in [text] as styled [TextSpan]s on top of [base].
List<TextSpan> markdownSpans(String text, TextStyle base, ColorScheme scheme) =>
    [
      for (final span in parseInline(text))
        TextSpan(
          text: span.text,
          style: switch (span.style) {
            InlineStyle.plain => base,
            InlineStyle.bold => base.copyWith(fontWeight: FontWeight.w700),
            InlineStyle.italic => base.copyWith(fontStyle: FontStyle.italic),
            InlineStyle.strikethrough => base.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
            InlineStyle.code => base.copyWith(
              fontFamily: 'monospace',
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          },
        ),
    ];
