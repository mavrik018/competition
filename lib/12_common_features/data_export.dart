/// Export (and import) data: CSV that opens correctly in Excel and Google
/// Sheets, pretty JSON, and a simple PDF report with a title, summary lines
/// and a table.
///
/// Newly written. StudyBuddies exported notes to PDF with the `pdf`
/// package inside a 470-line service tied to its note model; this keeps the
/// generic parts: rows in, bytes out. Combine with `ShareService` to send
/// the file anywhere.
///
/// ```dart
/// final csv = toCsv([
///   ['Date', 'Category', 'Amount'],
///   for (final e in expenses) [e.date.toIso8601String(), e.category, e.amount],
/// ]);
/// await share.shareFile(name: 'expenses.csv', bytes: utf8Bytes(csv, bom: true), mimeType: 'text/csv');
///
/// final pdf = await buildPdfReport(
///   title: 'Monthly expenses',
///   summary: {'Total': '\$1,240', 'Biggest category': 'Rent'},
///   headers: ['Date', 'Category', 'Amount'],
///   rows: [for (final e in expenses) [formatShortDate(e.date), e.category, e.amount.toStringAsFixed(2)]],
/// );
/// await share.shareFile(name: 'expenses.pdf', bytes: pdf, mimeType: 'application/pdf');
/// ```
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// RFC 4180 CSV. Cells containing a comma, quote, or line break are quoted,
/// quotes doubled. Lines end with CRLF, which every spreadsheet accepts.
/// `null` becomes an empty cell; other values use `toString()`.
String toCsv(List<List<Object?>> rows, {String separator = ','}) {
  String cell(Object? value) {
    final text = value?.toString() ?? '';
    final needsQuotes =
        text.contains(separator) ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
  }

  return rows.map((row) => row.map(cell).join(separator)).join('\r\n');
}

/// Parses CSV produced by [toCsv] or a spreadsheet: quoted cells, doubled
/// quotes, separators and line breaks inside quotes, CRLF or LF.
List<List<String>> parseCsv(String text, {String separator = ','}) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  final input = text.startsWith('﻿') ? text.substring(1) : text; // BOM

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == separator) {
      row.add(cell.toString());
      cell.clear();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(char);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

/// Turns a header row + data rows into maps: `[{Date: …, Amount: …}, …]`.
List<Map<String, String>> csvToMaps(List<List<String>> rows) {
  if (rows.isEmpty) return const [];
  final header = rows.first;
  return [
    for (final row in rows.skip(1))
      if (row.any((c) => c.isNotEmpty))
        {
          for (var i = 0; i < header.length; i++)
            header[i]: i < row.length ? row[i] : '',
        },
  ];
}

/// UTF-8 bytes. [bom] adds a byte-order mark so Excel on Windows reads
/// accented characters correctly in CSV files.
Uint8List utf8Bytes(String text, {bool bom = false}) => Uint8List.fromList([
  if (bom) ...[0xEF, 0xBB, 0xBF],
  ...utf8.encode(text),
]);

/// Indented JSON, for "export my data" features and debugging.
String toPrettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// A one-document PDF: title, optional subtitle and key/value summary, then
/// a table that continues across pages. Uses the PDF built-in Helvetica,
/// which covers Latin-1 only — for other scripts load a TTF with
/// `pw.Font.ttf(...)` and pass it as [font].
Future<Uint8List> buildPdfReport({
  required String title,
  String? subtitle,
  Map<String, String> summary = const {},
  List<String> headers = const [],
  List<List<String>> rows = const [],
  pw.Font? font,
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) {
  final document = pw.Document(title: title);
  final theme = font == null
      ? null
      : pw.ThemeData.withFont(base: font, bold: font);
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat,
      theme: theme,
      margin: const pw.EdgeInsets.all(36),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          title,
          style: const pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(color: PdfColors.grey700),
          ),
        ],
        if (summary.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          for (final entry in summary.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 160,
                    child: pw.Text(
                      entry.key,
                      style: const pw.TextStyle(color: PdfColors.grey700),
                    ),
                  ),
                  pw.Text(
                    entry.value,
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
        if (rows.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: headers.isEmpty ? null : headers,
            data: rows,
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 4,
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
          ),
        ],
      ],
    ),
  );
  return document.save();
}
