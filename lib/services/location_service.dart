import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'google_places_service.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  final GooglePlacesService _placesService = GooglePlacesService();
  List<GooglePlace>? cachedShops;
  DateTime? _fetchTime;
  double? cachedLatitude;
  double? cachedLongitude;

  bool _isCacheFresh(Duration maxAge) {
    if (_fetchTime == null) return false;
    return DateTime.now().difference(_fetchTime!) < maxAge;
  }

  Position? get cachedPosition {
    if (!_isCacheFresh(const Duration(minutes: 5))) return null;
    if (cachedLatitude == null || cachedLongitude == null) return null;
    return Position(
      latitude: cachedLatitude!,
      longitude: cachedLongitude!,
      timestamp: _fetchTime!,
      accuracy: 100,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  (double, double)? getFreshLatLng({
    Duration maxAge = const Duration(minutes: 5),
  }) {
    if (!_isCacheFresh(maxAge)) return null;
    if (cachedLatitude == null || cachedLongitude == null) return null;
    return (cachedLatitude!, cachedLongitude!);
  }

  List<GooglePlace>? getFreshCachedShops({
    Duration maxAge = const Duration(minutes: 5),
  }) {
    if (!_isCacheFresh(maxAge)) return null;
    return cachedShops;
  }

  Future<void> preFetchLocation({
    required String apiKey,
    Duration cacheMaxAge = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    if (apiKey.isEmpty) return;
    debugPrint(
      '[LocationService] preFetchLocation start. forceRefresh=$forceRefresh cacheFresh=${_isCacheFresh(cacheMaxAge)}',
    );
    if (forceRefresh) {
      cachedShops = null;
      cachedLatitude = null;
      cachedLongitude = null;
      _fetchTime = null;
    }
    if (!forceRefresh &&
        cachedShops != null &&
        cachedShops!.isNotEmpty &&
        _isCacheFresh(cacheMaxAge)) {
      debugPrint(
        '[LocationService] Using fresh cached shops (${cachedShops!.length})',
      );
      return;
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission denied: $permission');
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services disabled');
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(const Duration(seconds: 8));
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
      }
      position ??= await Geolocator.getLastKnownPosition();
      if (position == null) {
        debugPrint('[LocationService] No position available');
        return;
      }

      debugPrint(
        '[LocationService] Position acquired: ${position.latitude}, ${position.longitude}',
      );
      final shops = await _placesService.searchNearby(
        apiKey: apiKey,
        latitude: position.latitude,
        longitude: position.longitude,
        limit: 20,
        radiusMeters: 600,
        languageCode: 'ja',
      );

      cachedShops = shops;
      cachedLatitude = position.latitude;
      cachedLongitude = position.longitude;
      _fetchTime = DateTime.now();
      debugPrint('[LocationService] Places fetched: ${shops.length}');
    } catch (e, stack) {
      debugPrint('LocationService prefetch failed: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<(double, double)?> ensureLocation({
    required String apiKey,
    Duration cacheMaxAge = const Duration(minutes: 5),
  }) async {
    final cached = getFreshLatLng(maxAge: cacheMaxAge);
    if (cached != null) return cached;
    await preFetchLocation(
      apiKey: apiKey,
      cacheMaxAge: cacheMaxAge,
      forceRefresh: true,
    );
    return getFreshLatLng(maxAge: cacheMaxAge);
  }
}
