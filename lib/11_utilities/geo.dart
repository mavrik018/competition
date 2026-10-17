/// Great-circle distance between two coordinates.
///
/// Source: Couple `core/utils/haversine.dart`. Pure Dart on purpose:
/// `geolocator`'s own `distanceBetween` goes through a platform channel and
/// needs a registered plugin even though the maths does not, which makes it
/// awkward to unit-test.
///
/// ```dart
/// final km = distanceKm(51.5072, -0.1276, 40.7128, -74.0060); // ≈ 5570
/// Text(formatDistance(km)); // "5,570 km"
/// ```
library;

import 'dart:math' as math;

const double _earthRadiusKm = 6371.0088;

double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// "850 m" under one km, "12.4 km" under 100 km, otherwise "5,570 km".
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 100) return '${km.toStringAsFixed(1)} km';
  final whole = km.round().toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$grouped km';
}
