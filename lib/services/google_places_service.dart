import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const Set<String> _excludedTypes = {
  'restaurant',
  'cafe',
  'bar',
  'meal_takeaway',
  'bakery',
  'clothing_store',
  'shoe_store',
  'electronics_store',
  'furniture_store',
  'home_goods_store',
  'jewelry_store',
  'hardware_store',
  'book_store',
  'florist',
  'beauty_salon',
  'hair_care',
  'lodging',
  'school',
  'gym',
};

class GooglePlacesService {
  GooglePlacesService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PlaceAutocompletePrediction>> autocomplete({
    required String apiKey,
    required String input,
    double? latitude,
    double? longitude,
    double radiusMeters = 5000,
    String languageCode = 'ja',
  }) async {
    if (input.trim().isEmpty) return const <PlaceAutocompletePrediction>[];

    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places:autocomplete',
    );
    final body = <String, dynamic>{
      'input': input,
      'languageCode': languageCode,
      'includedPrimaryTypes': ['establishment'],
      if (latitude != null && longitude != null)
        'locationBias': {
          'circle': {
            'center': {'latitude': latitude, 'longitude': longitude},
            'radius': radiusMeters,
          },
        },
    };
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                // Use snake_case mask to match the API docs.
                'suggestions.place_prediction.place_id,'
                    'suggestions.place_prediction.distance_meters,'
                    'suggestions.place_prediction.structured_format,'
                    'suggestions.place_prediction.text',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Google Places Autocomplete error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('想定外のGoogle Places Autocompleteレスポンス');
    }
    final suggestionsJson = decoded['suggestions'];
    if (suggestionsJson is! List) {
      return const <PlaceAutocompletePrediction>[];
    }

    final results = <PlaceAutocompletePrediction>[];
    for (final item in suggestionsJson) {
      if (item is Map<String, dynamic>) {
        final parsed = PlaceAutocompletePrediction.fromJson(
          item['placePrediction'] as Map<String, dynamic>? ?? item,
        );
        if (parsed != null) {
          results.add(parsed);
        }
      }
    }
    return results;
  }

  Future<GooglePlace?> fetchPlaceDetails({
    required String apiKey,
    required String placeId,
    String languageCode = 'ja',
  }) async {
    final uri = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
    final response = await _client.get(
      uri,
      headers: {
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'displayName,location',
        'Accept-Language': languageCode,
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Google Place Details error ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final location = decoded['location'];
    final lat =
        location is Map<String, dynamic> ? location['latitude'] as num? : null;
    final lng =
        location is Map<String, dynamic> ? location['longitude'] as num? : null;
    final displayName = decoded['displayName'];
    final name = displayName is Map<String, dynamic>
        ? displayName['text'] as String?
        : decoded['name'] as String?;
    if (lat == null || lng == null || name == null) return null;
    return GooglePlace(
      name: name.trim(),
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      distanceMeters: null,
      types: null,
    );
  }

  Future<List<GooglePlace>> searchNearby({
    required String apiKey,
    required double latitude,
    required double longitude,
    int limit = 20,
    double radiusMeters = 600,
    String languageCode = 'ja',
  }) async {
    final uri = Uri.parse(
      'https://places.googleapis.com/v1/places:searchNearby',
    );
    final body = <String, dynamic>{
      'includedTypes': [
        'supermarket',
        'drugstore',
        'convenience_store',
        'grocery_store',
        'discount_store',
        'food_store',
      ],
      'rankPreference': 'DISTANCE',
      'maxResultCount': limit,
      'languageCode': languageCode,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': latitude, 'longitude': longitude},
          'radius': radiusMeters,
        },
      },
    };

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            // Limit fields to Basic Data to control costs.
            'X-Goog-FieldMask':
                'places.displayName,places.location,places.types',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception(
        'Google Places error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('想定外のGoogle Placesレスポンス');
    }

    final placesJson = decoded['places'];
    if (placesJson is! List) return <GooglePlace>[];

    final parsed = <GooglePlace>[];
    for (final item in placesJson) {
      if (item is Map<String, dynamic>) {
        final place = GooglePlace.fromJson(
          item,
          userLat: latitude,
          userLng: longitude,
        );
        if (place != null) {
          parsed.add(place);
        }
      }
    }
    return _filterConvenienceStores(parsed, limit);
  }

  void dispose() {
    _client.close();
  }
}

class GooglePlace {
  GooglePlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
    this.types,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double? distanceMeters;
  final List<String>? types;

  static GooglePlace? fromJson(
    Map<String, dynamic> json, {
    required double userLat,
    required double userLng,
  }) {
    final displayName = json['displayName'];
    final name = displayName is Map<String, dynamic>
        ? displayName['text'] as String?
        : null;
    final location = json['location'];
    final lat =
        location is Map<String, dynamic> ? location['latitude'] as num? : null;
    final lng =
        location is Map<String, dynamic> ? location['longitude'] as num? : null;
    final typesJson = json['types'];
    final types =
        typesJson is List ? typesJson.whereType<String>().toList() : null;

    if (name == null || name.trim().isEmpty || lat == null || lng == null) {
      return null;
    }

    final distance = _haversineMeters(
      userLat,
      userLng,
      lat.toDouble(),
      lng.toDouble(),
    );
    return GooglePlace(
      name: name.trim(),
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      distanceMeters: distance,
      types: types,
    );
  }
}

List<GooglePlace> _filterConvenienceStores(
  List<GooglePlace> places,
  int limit,
) {
  final result = <GooglePlace>[];
  var hasAddedConvenience = false;

  for (final place in places) {
    final typesLower =
        place.types?.map((t) => t.toLowerCase()).toList() ?? <String>[];
    final lowerName = place.name.toLowerCase().replaceAll(' ', '');
    final isMyBasket =
        lowerName.contains('mybasket') || lowerName.contains('まいばすけっと');
    if (isMyBasket) {
      if (kDebugMode) {
        debugPrint(
          '[Places] まいばすけっとを許可: ${place.name} 種類=$typesLower',
        );
      }
      result.add(place);
      if (result.length >= limit) break;
      continue;
    }

    final shouldExclude = typesLower.any(_excludedTypes.contains);
    if (shouldExclude) {
      if (kDebugMode) {
        debugPrint(
          '[Places] 除外タイプでスキップ: ${place.name} 種類=$typesLower',
        );
      }
      continue;
    }

    final isConvenience = typesLower.any((t) => t == 'convenience_store');
    final isSupermarketLike = typesLower.any(
      (t) =>
          t == 'supermarket' ||
          t == 'grocery_store' ||
          t == 'drugstore' ||
          t == 'food_store' ||
          t == 'discount_store',
    );
    if (isConvenience) {
      if (hasAddedConvenience) continue;
      hasAddedConvenience = true;
      result.add(place);
    } else if (isSupermarketLike) {
      result.add(place);
    } else {
      result.add(place);
    }
    if (result.length >= limit) break;
  }

  return result;
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000; // meters
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _toRadians(double deg) => deg * (math.pi / 180);

class PlaceAutocompletePrediction {
  PlaceAutocompletePrediction({
    required this.placeId,
    required this.primaryText,
    this.secondaryText,
    this.distanceMeters,
  });

  final String placeId;
  final String primaryText;
  final String? secondaryText;
  final double? distanceMeters;

  static PlaceAutocompletePrediction? fromJson(Map<String, dynamic> json) {
    final placeId = json['placeId'] as String? ?? json['place_id'] as String?;
    if (placeId == null || placeId.isEmpty) return null;

    String? primary;
    String? secondary;

    String? _extractText(dynamic value) {
      if (value is String) return value;
      if (value is Map<String, dynamic>) {
        final text = value['text'];
        if (text is String) return text;
      }
      return null;
    }

    final structured = json['structuredFormat'] ?? json['structured_format'];
    if (structured is Map<String, dynamic>) {
      primary = _extractText(structured['mainText']) ??
          _extractText(structured['main_text']);
      secondary = _extractText(structured['secondaryText']) ??
          _extractText(structured['secondary_text']);
    }
    final text = json['text'];
    final fallback = _extractText(text) ?? json['description'] as String?;
    primary ??= fallback;
    if (primary == null || primary.trim().isEmpty) return null;

    final dist =
        json['distanceMeters'] as num? ?? json['distance_meters'] as num?;
    return PlaceAutocompletePrediction(
      placeId: placeId,
      primaryText: primary.trim(),
      secondaryText: secondary?.trim(),
      distanceMeters: dist?.toDouble(),
    );
  }
}
