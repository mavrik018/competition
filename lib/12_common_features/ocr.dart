/// Text recognition from photos (OCR) plus rule-based extraction of the
/// useful bits: amounts and the total, dates, emails, phone numbers, URLs.
///
/// **What is AI here and what is not.** Recognition ([MlKitTextRecognizer])
/// runs Google ML Kit's on-device machine-learning model — that part *is*
/// ML, but it runs offline with no API key. Everything after it
/// ([extractFromText]) is plain rules (regular expressions and keyword
/// matching) — deterministic, explainable, and testable.
///
/// Newly written. StudyBuddies sent page photos to a cloud LLM for
/// handwriting; for printed text (receipts, labels, forms) on-device OCR is
/// free, private and works offline.
///
/// ```dart
/// final recognizer = MlKitTextRecognizer();          // FakeTextRecognizer in tests
/// final photo = await picker.pickImage(source: MediaSource.camera);
/// final text = await recognizer.recognizeFile(photo!.path!);
/// final data = extractFromText(text);
/// amountController.text = data.total?.toStringAsFixed(2) ?? '';
/// ```
///
/// **Platforms:** ML Kit supports Android and iOS only (min iOS 15.5,
/// Android minSdk 21). On web/desktop use a cloud OCR behind an Edge
/// Function implementing [TextRecognizerService].
library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract interface class TextRecognizerService {
  /// All text found in the image at [path] ('' if none).
  Future<String> recognizeFile(String path);
  Future<void> close();
}

/// On-device recognition (Latin script) with Google ML Kit.
class MlKitTextRecognizer implements TextRecognizerService {
  MlKitTextRecognizer({
    TextRecognitionScript script = TextRecognitionScript.latin,
  }) : _recognizer = TextRecognizer(script: script);

  final TextRecognizer _recognizer;

  @override
  Future<String> recognizeFile(String path) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(path),
    );
    return result.text;
  }

  @override
  Future<void> close() => _recognizer.close();
}

/// Returns fixed text for any image. **A test double, not OCR.**
class FakeTextRecognizer implements TextRecognizerService {
  FakeTextRecognizer(this.text);
  final String text;
  final recognizedPaths = <String>[];

  @override
  Future<String> recognizeFile(String path) async {
    recognizedPaths.add(path);
    return text;
  }

  @override
  Future<void> close() async {}
}

class ExtractedText {
  const ExtractedText({
    required this.amounts,
    required this.total,
    required this.dates,
    required this.emails,
    required this.phones,
    required this.urls,
  });

  /// Every money-looking number, in reading order.
  final List<double> amounts;

  /// The amount on a "total" line, else the largest amount; null if none.
  final double? total;
  final List<DateTime> dates;
  final List<String> emails;
  final List<String> phones;
  final List<String> urls;
}

/// Rule-based extraction from OCR text.
///
/// Amounts: numbers with exactly two decimals (`12.50`, `12,50`,
/// `1,234.50`), optionally after a currency symbol. Total: the last line
/// containing one of [totalKeywords] (case-insensitive) that has an amount.
/// Dates: `2026-10-14`, `14/10/2026`, `14.10.26`, `Oct 14, 2026`,
/// `14 Oct 2026` — numeric dates are read day-first unless [monthFirst].
ExtractedText extractFromText(
  String text, {
  List<String> totalKeywords = const [
    'grand total',
    'total',
    'amount due',
    'balance due',
    'to pay',
  ],
  bool monthFirst = false,
}) {
  final lines = text.split(RegExp(r'\r?\n'));
  final amountPattern = RegExp(
    r'(?<![\d.,])(\d{1,3}(?:[ ,.]\d{3})*|\d+)[.,](\d{2})(?![\d])',
  );

  List<double> amountsIn(String line) => [
    for (final m in amountPattern.allMatches(line))
      double.parse('${m[1]!.replaceAll(RegExp(r'[ ,.]'), '')}.${m[2]}'),
  ];

  final amounts = [for (final line in lines) ...amountsIn(line)];

  double? total;
  for (final line in lines.reversed) {
    final lower = line.toLowerCase();
    if (lower.contains('subtotal') && !lower.contains('grand')) continue;
    if (totalKeywords.any(lower.contains)) {
      final found = amountsIn(line);
      if (found.isNotEmpty) {
        total = found.last;
        break;
      }
    }
  }
  total ??= amounts.isEmpty ? null : amounts.reduce((a, b) => a > b ? a : b);

  return ExtractedText(
    amounts: amounts,
    total: total,
    dates: _dates(text, monthFirst: monthFirst),
    emails: [
      for (final m in RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+').allMatches(text))
        m[0]!,
    ],
    phones: _phones(text),
    urls: [
      for (final m in RegExp(r'(https?://|www\.)[^\s]+').allMatches(text))
        m[0]!,
    ],
  );
}

/// Runs of digits (with spaces, dots, dashes, brackets, a leading +) that
/// contain 7–15 digits and are not dates or money amounts.
List<String> _phones(String text) {
  final candidates = RegExp(r'(?<![\w])\+?\d[\d\s().-]{5,}\d').allMatches(text);
  final looksLikeDate = RegExp(r'^\d{1,4}[./-]\d{1,2}[./-]\d{1,4}$');
  final looksLikeAmount = RegExp(r'\d[.,]\d{2}$');
  return [
    for (final m in candidates)
      if (_digitCount(m[0]!) >= 7 &&
          _digitCount(m[0]!) <= 15 &&
          !looksLikeDate.hasMatch(m[0]!.trim()) &&
          !looksLikeAmount.hasMatch(m[0]!.trim()))
        m[0]!.trim(),
  ];
}

int _digitCount(String text) => text.replaceAll(RegExp(r'\D'), '').length;

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

List<DateTime> _dates(String text, {required bool monthFirst}) {
  final found = <DateTime>[];
  void add(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return;
    final date = DateTime(y, m, d);
    if (date.month == m) found.add(date); // rejects 31 Feb etc.
  }

  for (final m in RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').allMatches(text)) {
    add(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  for (final m in RegExp(
    r'\b(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})\b',
  ).allMatches(text)) {
    final a = int.parse(m[1]!);
    final b = int.parse(m[2]!);
    monthFirst ? add(int.parse(m[3]!), a, b) : add(int.parse(m[3]!), b, a);
  }
  for (final m in RegExp(
    r'\b([A-Za-z]{3})[a-z]*\.? (\d{1,2}),? (\d{4})\b',
  ).allMatches(text)) {
    final month = _months[m[1]!.toLowerCase()];
    if (month != null) add(int.parse(m[3]!), month, int.parse(m[2]!));
  }
  for (final m in RegExp(
    r'\b(\d{1,2}) ([A-Za-z]{3})[a-z]*\.? (\d{4})\b',
  ).allMatches(text)) {
    final month = _months[m[2]!.toLowerCase()];
    if (month != null) add(int.parse(m[3]!), month, int.parse(m[1]!));
  }
  return found;
}
