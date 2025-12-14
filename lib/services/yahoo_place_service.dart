import 'dart:convert';

import 'package:http/http.dart' as http;

class YahooPlaceService {
  YahooPlaceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<YahooPlace>> searchNearby({
    required String appId,
    required double latitude,
    required double longitude,
    int limit = 5,
    int distanceMeters = 300,
    List<String>? categoryCodes,
  }) async {
    final boundedDistance = distanceMeters.clamp(1, 5000);
    final query = <String, String>{
      'appid': appId,
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'dist': '$boundedDistance',
      'output': 'json',
      'sort': 'dist',
    };

    final filteredCategories =
        categoryCodes?.where((code) => code.trim().isNotEmpty).toList() ?? [];
    if (filteredCategories.isNotEmpty) {
      query['gc'] = filteredCategories.join(',');
    }

    final uri =
        Uri.parse('https://map.yahooapis.jp/search/local/V1/localSearch')
            .replace(queryParameters: query);

    final response =
        await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Yahoo APIエラー ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('想定外のYahoo APIレスポンス');
    }
    final features = decoded['Feature'];
    if (features is! List) {
      return <YahooPlace>[];
    }

    final places = <YahooPlace>[];
    for (final item in features) {
      if (item is Map<String, dynamic>) {
        final parsed = YahooPlace.fromJson(item);
        if (parsed != null) {
          places.add(parsed);
        }
      }
      if (places.length >= limit) break;
    }
    return places;
  }

  void dispose() {
    _client.close();
  }
}

class YahooPlace {
  YahooPlace({
    required this.name,
    this.address,
    this.distanceMeters,
  });

  final String name;
  final String? address;
  final double? distanceMeters;

  static YahooPlace? fromJson(Map<String, dynamic> json) {
    final nameValue = json['Name'];
    if (nameValue is! String || nameValue.trim().isEmpty) {
      return null;
    }
    String? address;
    double? distance;
    final property = json['Property'];
    if (property is Map) {
      final addressValue = property['Address'];
      if (addressValue is String && addressValue.isNotEmpty) {
        address = addressValue;
      }
      final distanceValue = property['Distance'] ?? property['distance'];
      if (distanceValue != null) {
        distance = double.tryParse(distanceValue.toString());
      }
    }
    return YahooPlace(
      name: nameValue.trim(),
      address: address,
      distanceMeters: distance,
    );
  }
}
