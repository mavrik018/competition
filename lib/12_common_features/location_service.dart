/// Device location behind an interface (real `geolocator` implementation +
/// a scripted fake), plus pure helpers that need no GPS: geofences, nearest
/// places, and filtering by distance.
///
/// Source: Couple's distance card (`geolocator` + its own haversine).
/// Generalised; the haversine maths is reused from `11_utilities/geo.dart`.
///
/// ```dart
/// final location = ref.read(locationServiceProvider);     // GeolocatorLocationService in the app
/// final here = await location.currentPosition();          // throws LocationException with a reason
/// final closest = nearestPlaces(places, here, positionOf: (p) => p.point, limit: 5);
///
/// final campus = Geofence(GeoPoint(51.5246, -0.1340), radiusMeters: 300);
/// location.positions().listen((p) {
///   if (campus.contains(p)) autoCheckIn();
/// });
/// ```
///
/// **Platform setup** (`geolocator`): Android `ACCESS_FINE_LOCATION` /
/// `ACCESS_COARSE_LOCATION` in the manifest; iOS
/// `NSLocationWhenInUseUsageDescription`. Background location needs extra
/// setup and store justification — avoid unless essential.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../11_utilities/geo.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  double distanceKmTo(GeoPoint other) =>
      distanceKm(latitude, longitude, other.latitude, other.longitude);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

enum LocationProblem { servicesDisabled, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.problem);
  final LocationProblem problem;

  String get message => switch (problem) {
    LocationProblem.servicesDisabled =>
      'Location is turned off on this device.',
    LocationProblem.denied => 'Location permission was not granted.',
    LocationProblem.deniedForever =>
      'Location is blocked for this app. Enable it in Settings.',
    LocationProblem.unavailable => "Your location couldn't be found right now.",
  };

  @override
  String toString() => 'LocationException(${problem.name})';
}

abstract interface class LocationService {
  /// Asks for permission if needed. Throws [LocationException].
  Future<GeoPoint> currentPosition();

  /// Updates as the device moves at least [distanceFilterMeters].
  Stream<GeoPoint> positions({int distanceFilterMeters = 25});
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService({this.timeout = const Duration(seconds: 15)});

  final Duration timeout;

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationProblem.servicesDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationProblem.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationProblem.denied);
    }
  }

  @override
  Future<GeoPoint> currentPosition() async {
    await _ensurePermission();
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return GeoPoint(p.latitude, p.longitude);
    } on TimeoutException {
      // Fall back to the last known fix rather than failing outright.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GeoPoint(last.latitude, last.longitude);
      throw const LocationException(LocationProblem.unavailable);
    }
  }

  @override
  Stream<GeoPoint> positions({int distanceFilterMeters = 25}) async* {
    await _ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(distanceFilter: distanceFilterMeters),
    ).map((p) => GeoPoint(p.latitude, p.longitude));
  }
}

/// Plays back fixed positions. **A test/demo double — no GPS is used.**
class FakeLocationService implements LocationService {
  FakeLocationService(this.route, {this.problem});

  /// [currentPosition] returns the first point; [positions] emits them all.
  final List<GeoPoint> route;

  /// When set, every call throws this problem (to test error UI).
  final LocationProblem? problem;

  @override
  Future<GeoPoint> currentPosition() async {
    if (problem != null) throw LocationException(problem!);
    if (route.isEmpty) {
      throw const LocationException(LocationProblem.unavailable);
    }
    return route.first;
  }

  @override
  Stream<GeoPoint> positions({int distanceFilterMeters = 25}) {
    if (problem != null) return Stream.error(LocationException(problem!));
    return Stream.fromIterable(route);
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// A circular area. GPS is accurate to roughly 5–50 m, so radii under ~50 m
/// will flicker in and out.
class Geofence {
  const Geofence(this.center, {required this.radiusMeters});
  final GeoPoint center;
  final double radiusMeters;

  bool contains(GeoPoint point) =>
      center.distanceKmTo(point) * 1000 <= radiusMeters;
}

/// [items] sorted by distance from [from], nearest first, optionally only
/// those within [maxKm] and at most [limit]. Each comes with its distance.
List<({T item, double km})> nearestPlaces<T>(
  Iterable<T> items,
  GeoPoint from, {
  required GeoPoint Function(T item) positionOf,
  double? maxKm,
  int? limit,
}) {
  final withDistance = [
    for (final item in items)
      (item: item, km: positionOf(item).distanceKmTo(from)),
  ]..sort((a, b) => a.km.compareTo(b.km));
  final filtered = maxKm == null
      ? withDistance
      : withDistance.where((e) => e.km <= maxKm).toList();
  return limit == null ? filtered : filtered.take(limit).toList();
}
