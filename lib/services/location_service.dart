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
      '[LocationService] 事前取得開始 forceRefresh=$forceRefresh cacheFresh=${_isCacheFresh(cacheMaxAge)}',
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
        '[LocationService] キャッシュ済み店舗を再利用 (${cachedShops!.length}件)',
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
        debugPrint('[LocationService] 位置情報の許可がありません: $permission');
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] 位置情報サービスがオフです');
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
        debugPrint('[LocationService] 位置を取得できません');
        return;
      }

      debugPrint(
        '[LocationService] 位置取得: ${position.latitude}, ${position.longitude}',
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
      debugPrint('[LocationService] 店舗候補を取得: ${shops.length}件');
    } catch (e, stack) {
      debugPrint('LocationServiceの事前取得に失敗: $e');
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
