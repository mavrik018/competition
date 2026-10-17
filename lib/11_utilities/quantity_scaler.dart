/// Scales free-text amounts like "2-3 cloves", "1 1/2 cups" or "400g" by a
/// factor — for changing a recipe's servings, a pack size, a dose.
///
/// Source: Cookly `features/recipe/application/servings_scaler.dart`. Kept:
/// ranges, mixed numbers, fractions and plain numbers; counts round to a
/// whole number and never drop below 1 ("1.5 eggs" is not a quantity), while
/// weights and volumes keep decimals; anything unparseable is returned
/// unchanged. Changed: Cookly looked unit words up in its own `Unit` model;
/// here the measured units are a plain set you can extend.
///
/// ```dart
/// scaleQuantity('2-3 cloves', 2);  // "4-6 cloves"
/// scaleQuantity('1 1/2 cups', 2);  // "3 cups"
/// scaleQuantity('3', 0.5);         // "2"   (a count: rounds, min 1)
/// scaleQuantity('250 g', 0.5);     // "125 g"
/// ```
library;

import 'number_format.dart';

/// Unit words that measure (weight/volume/length) and so keep decimals.
/// Anything else — or no unit — is treated as a count.
const defaultMeasuredUnits = <String>{
  'g', 'gram', 'grams', 'kg', 'kgs', 'kilogram', 'kilograms', //
  'mg', 'oz', 'ounce', 'ounces', 'lb', 'lbs', 'pound', 'pounds',
  'ml', 'millilitre', 'milliliter', 'millilitres', 'milliliters',
  'l', 'litre', 'liter', 'litres', 'liters', 'dl', 'cl',
  'cup', 'cups', 'tbsp', 'tablespoon', 'tablespoons', 'tsp', 'teaspoon',
  'teaspoons', 'pint', 'pints', 'quart', 'quarts', 'gallon', 'gallons',
  'fl', 'cm', 'mm', 'm', 'inch', 'inches', 'in',
};

final _range = RegExp(r'^(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\s*(.*)$');
final _mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)\s*(.*)$');
final _fraction = RegExp(r'^(\d+)/(\d+)\s*(.*)$');
final _plain = RegExp(r'^(\d+(?:\.\d+)?)(\s*)(.*)$');

String scaleQuantity(
  String amount,
  double factor, {
  Set<String> measuredUnits = defaultMeasuredUnits,
}) {
  final text = amount.trim();
  if (text.isEmpty || factor == 1) return amount;

  bool isCount(String rest) {
    final word = rest.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return word.isEmpty || !measuredUnits.contains(word.replaceAll('.', ''));
  }

  String scale(double value, String rest) {
    final scaled = value * factor;
    final shown = isCount(rest)
        ? formatQuantity(scaled.round() < 1 ? 1 : scaled.round())
        : formatQuantity(scaled);
    return shown;
  }

  String withRest(String number, String rest, [String gap = ' ']) =>
      rest.isEmpty ? number : '$number$gap$rest';

  final range = _range.firstMatch(text);
  if (range != null) {
    final rest = range[3]!;
    final low = scale(double.parse(range[1]!), rest);
    final high = scale(double.parse(range[2]!), rest);
    return withRest('$low-$high', rest);
  }

  // A zero denominator is malformed: return it untouched rather than letting
  // the plain-number rule below scale just its leading digit.
  final mixed = _mixed.firstMatch(text);
  if (mixed != null) {
    if (int.parse(mixed[3]!) == 0) return amount;
    final value =
        int.parse(mixed[1]!) + int.parse(mixed[2]!) / int.parse(mixed[3]!);
    return withRest(scale(value, mixed[4]!), mixed[4]!);
  }

  final fraction = _fraction.firstMatch(text);
  if (fraction != null) {
    if (int.parse(fraction[2]!) == 0) return amount;
    final value = int.parse(fraction[1]!) / int.parse(fraction[2]!);
    return withRest(scale(value, fraction[3]!), fraction[3]!);
  }

  final plain = _plain.firstMatch(text);
  if (plain != null) {
    // Preserve "400g" vs "400 g" as the author wrote it.
    return withRest(
      scale(double.parse(plain[1]!), plain[3]!),
      plain[3]!,
      plain[2]!,
    );
  }

  return amount;
}
