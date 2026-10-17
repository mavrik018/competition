/// Small number formatters for display.
///
/// Source: Cookly `core/ingredients/format_number.dart` ([formatQuantity]);
/// [formatBytes] and [formatCompact] are generalised from StudyBuddies'
/// upload progress ("3.2 MB of 8.0 MB") and stat badges; [formatDuration]
/// is newly written.
library;

/// Whole numbers without a decimal point; fractions to at most
/// [maxDecimals] places without trailing zeros. 2.0 → "2", 1.50 → "1.5",
/// 0.333… → "0.33".
String formatQuantity(num value, {int maxDecimals = 2}) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value
      .toStringAsFixed(maxDecimals)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// 950 → "950", 1200 → "1.2k", 3400000 → "3.4M".
String formatCompact(num value) {
  final abs = value.abs();
  if (abs < 1000) return formatQuantity(value, maxDecimals: 1);
  if (abs < 1000000) return '${formatQuantity(value / 1000, maxDecimals: 1)}k';
  if (abs < 1000000000) {
    return '${formatQuantity(value / 1000000, maxDecimals: 1)}M';
  }
  return '${formatQuantity(value / 1000000000, maxDecimals: 1)}B';
}

/// 512 → "512 B", 2048 → "2.0 KB", 3355443 → "3.2 MB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// 45s → "45s", 5m 3s → "5m 03s", 1h 5m → "1h 05m".
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (hours > 0) return '${hours}h ${two(minutes)}m';
  if (minutes > 0) return '${minutes}m ${two(seconds)}s';
  return '${seconds}s';
}
