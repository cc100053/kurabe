import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'google_places_service.dart';

enum LocationFailureReason {
  permissionDenied,
  serviceDisabled,
  timeout,
  unavailable,
}

enum LocationSource { cache, lastKnown, current }

class LocationFailure {
  const LocationFailure(this.reason);

  final LocationFailureReason reason;
}

class LocationResult {
  const LocationResult.success({
    required this.position,
    required this.source,
  }) : failure = null;

  const LocationResult.failure(this.failure)
      : position = null,
        source = null;

  final Position? position;
  final LocationFailure? failure;
  final LocationSource? source;

  bool get hasLocation => position != null;
}

class LocationRepository {
  LocationRepository._({GooglePlacesService? placesService})
      : _placesService = placesService ?? GooglePlacesService();

  static final LocationRepository instance = LocationRepository._();

  final GooglePlacesService _placesService;
  Position? _cachedPosition;
  DateTime? _positionFetchedAt;
  List<GooglePlace>? _cachedShops;
  DateTime? _shopsFetchedAt;

  bool _isFresh(DateTime? fetchedAt, Duration maxAge) {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < maxAge;
  }

  Position? _getCachedPosition(Duration maxAge) {
    if (!_isFresh(_positionFetchedAt, maxAge)) return null;
    return _cachedPosition;
  }

  Position? get cachedPosition =>
      _getCachedPosition(const Duration(minutes: 5));

  (double, double)? getFreshLatLng({
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final cached = _getCachedPosition(maxAge);
    if (cached == null) return null;
    return (cached.latitude, cached.longitude);
  }

  List<GooglePlace>? getFreshCachedShops({
    Duration maxAge = const Duration(minutes: 5),
  }) {
    if (!_isFresh(_shopsFetchedAt, maxAge)) return null;
    return _cachedShops;
  }

  Future<LocationResult> ensurePosition({
    bool highAccuracy = false,
    Duration cacheMaxAge = const Duration(minutes: 5),
    bool requestPermission = true,
  }) async {
    final cached = _getCachedPosition(cacheMaxAge);
    if (cached != null) {
      return LocationResult.success(
        position: cached,
        source: LocationSource.cache,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        LocationFailure(LocationFailureReason.permissionDenied),
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult.failure(
        LocationFailure(LocationFailureReason.serviceDisabled),
      );
    }

    Position? position;
    var usedLastKnown = false;
    var timedOut = false;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy ? LocationAccuracy.high : LocationAccuracy.low,
      ).timeout(
        highAccuracy ? const Duration(seconds: 10) : const Duration(seconds: 6),
      );
    } on TimeoutException {
      position = null;
      timedOut = true;
    } catch (_) {
      position = null;
    }

    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
        usedLastKnown = position != null;
      } catch (_) {
        position = null;
      }
    }

    if (position == null) {
      return LocationResult.failure(
        LocationFailure(
          timedOut
              ? LocationFailureReason.timeout
              : LocationFailureReason.unavailable,
        ),
      );
    }

    _cachedPosition = position;
    _positionFetchedAt = DateTime.now();
    return LocationResult.success(
      position: position,
      source: usedLastKnown ? LocationSource.lastKnown : LocationSource.current,
    );
  }

  Future<(double, double)?> ensureLocation({
    Duration cacheMaxAge = const Duration(minutes: 5),
  }) async {
    final result = await ensurePosition(cacheMaxAge: cacheMaxAge);
    if (!result.hasLocation) return null;
    final pos = result.position!;
    return (pos.latitude, pos.longitude);
  }

  Future<List<GooglePlace>> preFetchLocation({
    required String apiKey,
    Duration cacheMaxAge = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    return fetchNearbyShops(
      apiKey: apiKey,
      cacheMaxAge: cacheMaxAge,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<GooglePlace>> fetchNearbyShops({
    required String apiKey,
    Duration cacheMaxAge = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) async {
    if (apiKey.isEmpty) return const <GooglePlace>[];
    if (!forceRefresh &&
        _cachedShops != null &&
        _cachedShops!.isNotEmpty &&
        _isFresh(_shopsFetchedAt, cacheMaxAge)) {
      return _cachedShops!;
    }

    final positionResult =
        await ensurePosition(cacheMaxAge: cacheMaxAge, requestPermission: true);
    if (!positionResult.hasLocation) {
      return const <GooglePlace>[];
    }

    final position = positionResult.position!;
    try {
      final shops = await _placesService.searchNearby(
        apiKey: apiKey,
        latitude: position.latitude,
        longitude: position.longitude,
        limit: 20,
        radiusMeters: 600,
        languageCode: 'ja',
      );
      _cachedShops = shops;
      _shopsFetchedAt = DateTime.now();
      return shops;
    } catch (e, stack) {
      debugPrint('LocationRepository fetchNearbyShops failed: $e');
      debugPrintStack(stackTrace: stack);
      return const <GooglePlace>[];
    }
  }

  String messageForFailure(LocationFailureReason? reason) {
    switch (reason) {
      case LocationFailureReason.permissionDenied:
        return '位置情報の許可が必要です。設定からオンにしてください。';
      case LocationFailureReason.serviceDisabled:
        return '位置情報サービスをオンにしてください。';
      case LocationFailureReason.timeout:
        return '現在地の取得がタイムアウトしました。通信環境を確認してください。';
      case LocationFailureReason.unavailable:
      default:
        return '現在地を取得できませんでした。電波状況を確認して再試行してください。';
    }
  }

  Future<void> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
