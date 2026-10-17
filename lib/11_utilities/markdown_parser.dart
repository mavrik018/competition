/// A parser for the small Markdown subset AI models and note editors
/// actually produce: headings, bullet and numbered lists, fenced code,
/// pipe tables, and inline bold / italic / code / strikethrough.
///
/// Source: StudyBuddies `core/utils/markdown_tokens.dart`. It exists because
/// the app rendered Markdown in two places (on screen and in PDF export)
/// and the two hand-written parsers drifted apart. Parsing once into plain
/// Dart objects lets any number of renderers share it — see `MarkdownView`
/// in 02_ui_elements for the Flutter one. Inline strikethrough (`~~x~~`)
/// was added from TaskFlow's `rich_text_parser.dart`; TaskFlow's `_x_`
/// underline was not, because it mangles snake_case words.
///
/// Pure Dart — no Flutter import — so it also runs in an isolate or a
/// server.
///
/// ```dart
/// for (final block in parseMarkdown(text)) {
///   switch (block) {
///     case MarkdownHeading(:final level, :final text): …
///     case MarkdownBullet(:final text): …
///     …
///   }
/// }
/// ```
library;

sealed class MarkdownBlock {
  const MarkdownBlock();
}

/// A blank line — vertical space, not an empty paragraph.
class MarkdownBlank extends MarkdownBlock {
  const MarkdownBlank();
}

/// `#` … `######`. [level] is 1–6.
class MarkdownHeading extends MarkdownBlock {
  const MarkdownHeading(this.level, this.text);
  final int level;
  final String text;
}

/// `- item`, `* item` or `+ item`. [indent] is the nesting depth (two
/// spaces or one tab per level).
class MarkdownBullet extends MarkdownBlock {
  const MarkdownBullet(this.text, {this.indent = 0});
  final String text;
  final int indent;
}

/// `3. item`. [number] keeps the author's own numbering.
class MarkdownNumbered extends MarkdownBlock {
  const MarkdownNumbered(this.number, this.text, {this.indent = 0});
  final String number;
  final String text;
  final int indent;
}

/// A fenced block. [code] is verbatim: never trimmed, never parsed inline —
/// leading spaces align diagrams and `*` in a shell command is a glob.
class MarkdownCode extends MarkdownBlock {
  const MarkdownCode(this.code, this.language);
  final String code;
  final String language;
}

/// A pipe table. [rows] excludes the `|---|` separator; every row is padded
/// to the widest row so a ragged table never throws.
class MarkdownTable extends MarkdownBlock {
  const MarkdownTable(this.rows, {required this.hasHeader});
  final List<List<String>> rows;
  final bool hasHeader;
}

/// `> quoted text`.
class MarkdownQuote extends MarkdownBlock {
  const MarkdownQuote(this.text);
  final String text;
}

class MarkdownParagraph extends MarkdownBlock {
  const MarkdownParagraph(this.text);
  final String text;
}

final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$');
final _numbered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
final _quote = RegExp(r'^\s*>\s?(.*)$');
final _fence = RegExp(r'^\s*```\s*([\w+-]*)\s*$');
final _tableRow = RegExp(r'^\s*\|.*\|\s*$');
final _tableDivider = RegExp(r'^\s*\|[\s:|-]+\|\s*$');

int _indentOf(String leading) => leading.replaceAll('\t', '  ').length ~/ 2;

/// Splits `| a | b |` into `['a', 'b']`, keeping escaped `\|` as a literal
/// pipe inside a cell.
List<String> _splitRow(String line) {
  const placeholder = '\u0000';
  var body = line.trim().replaceAll(r'\|', placeholder);
  if (body.startsWith('|')) body = body.substring(1);
  if (body.endsWith('|')) body = body.substring(0, body.length - 1);
  return [
    for (final cell in body.split('|'))
      cell.replaceAll(placeholder, '|').trim(),
  ];
}

/// Classifies one line, ignoring context (fences and tables span lines —
/// use [parseMarkdown] for whole documents).
MarkdownBlock parseMarkdownLine(String rawLine) {
  final line = rawLine.trimRight();
  if (line.trim().isEmpty) return const MarkdownBlank();

  final heading = _heading.firstMatch(line);
  if (heading != null) return MarkdownHeading(heading[1]!.length, heading[2]!);

  final bullet = _bullet.firstMatch(line);
  if (bullet != null) {
    return MarkdownBullet(bullet[2]!, indent: _indentOf(bullet[1]!));
  }

  final numbered = _numbered.firstMatch(line);
  if (numbered != null) {
    return MarkdownNumbered(
      numbered[2]!,
      numbered[3]!,
      indent: _indentOf(numbered[1]!),
    );
  }

  final quote = _quote.firstMatch(line);
  if (quote != null) return MarkdownQuote(quote[1]!);

  return MarkdownParagraph(line.trim());
}

/// Parses a whole document into blocks.
///
/// An unterminated fence runs to the end of the document (CommonMark does
/// the same): rendering too much as code loses styling, while the
/// alternative loses the author's layout. A single `| row |` line is prose;
/// a table needs at least two consecutive rows.
List<MarkdownBlock> parseMarkdown(String text) {
  final blocks = <MarkdownBlock>[];
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  var i = 0;

  while (i < lines.length) {
    final fence = _fence.firstMatch(lines[i]);
    if (fence != null) {
      final body = <String>[];
      i++;
      while (i < lines.length && !_fence.hasMatch(lines[i])) {
        body.add(lines[i]);
        i++;
      }
      if (i < lines.length) i++; // closing fence
      blocks.add(MarkdownCode(body.join('\n'), fence[1] ?? ''));
      continue;
    }

    if (_tableRow.hasMatch(lines[i])) {
      var end = i;
      while (end < lines.length && _tableRow.hasMatch(lines[end])) {
        end++;
      }
      if (end - i >= 2) {
        final raw = lines.sublist(i, end);
        final hasHeader = _tableDivider.hasMatch(raw[1]);
        final rows = [
          for (final line in raw)
            if (!_tableDivider.hasMatch(line)) _splitRow(line),
        ];
        final width = rows.fold<int>(
          0,
          (w, row) => row.length > w ? row.length : w,
        );
        blocks.add(
          MarkdownTable([
            for (final row in rows)
              [...row, ...List.filled(width - row.length, '')],
          ], hasHeader: hasHeader),
        );
        i = end;
        continue;
      }
    }

    blocks.add(parseMarkdownLine(lines[i]));
    i++;
  }
  return blocks;
}

enum InlineStyle { plain, bold, italic, code, strikethrough }

/// A run of text with one style.
class InlineSpanData {
  const InlineSpanData(this.text, this.style);
  final String text;
  final InlineStyle style;

  @override
  bool operator ==(Object other) =>
      other is InlineSpanData && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(text, style);

  @override
  String toString() => '${style.name}("$text")';
}

/// `**bold**`, `~~strike~~`, `*italic*`, `` `code` `` — longest markers
/// first so `**` is never read as two italics.
final _inline = RegExp(r'(\*\*[^*]+\*\*|~~[^~]+~~|\*[^*\s][^*]*\*|`[^`]+`)');

/// Splits [text] into styled runs, in order. Unmatched markers stay as
/// literal text.
List<InlineSpanData> parseInline(String text) {
  final spans = <InlineSpanData>[];
  var start = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > start) {
      spans.add(
        InlineSpanData(text.substring(start, match.start), InlineStyle.plain),
      );
    }
    final token = match[0]!;
    final (inner, style) = switch (token) {
      _ when token.startsWith('**') => (
        token.substring(2, token.length - 2),
        InlineStyle.bold,
      ),
      _ when token.startsWith('~~') => (
        token.substring(2, token.length - 2),
        InlineStyle.strikethrough,
      ),
      _ when token.startsWith('`') => (
        token.substring(1, token.length - 1),
        InlineStyle.code,
      ),
      _ => (token.substring(1, token.length - 1), InlineStyle.italic),
    };
    spans.add(InlineSpanData(inner, style));
    start = match.end;
  }
  if (start < text.length) {
    spans.add(InlineSpanData(text.substring(start), InlineStyle.plain));
  }
  return spans;
}
