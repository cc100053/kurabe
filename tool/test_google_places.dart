import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final env = await _loadEnv('.env');
  final apiKey = env['GOOGLE_PLACES_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Missing GOOGLE_PLACES_API_KEY in .env');
    exit(1);
  }

  final latitude = _readArg(args, '--lat') ?? '35.658034'; // Shibuya
  final longitude = _readArg(args, '--lon') ?? '139.701636';
  final radius = _readArg(args, '--dist') ?? '500';

  final uri = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
  final body = <String, dynamic>{
    'includedTypes': ['supermarket', 'drugstore', 'convenience_store', 'shopping_mall'],
    'maxResultCount': 5,
    'locationRestriction': {
      'circle': {
        'center': {'latitude': double.parse(latitude), 'longitude': double.parse(longitude)},
        'radius': double.parse(radius),
      }
    },
  };

  stdout.writeln('Requesting $uri with radius $radius m');
  try {
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': 'places.displayName,places.location',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    stdout.writeln('HTTP ${response.statusCode}');
    if (response.statusCode != 200) {
      stderr.writeln('Body: ${response.body}');
      exit(1);
    }

    final decoded = jsonDecode(response.body);
    final places = decoded is Map<String, dynamic> ? decoded['places'] : null;
    if (places is List && places.isNotEmpty) {
      stdout.writeln('Found ${places.length} results');
      for (final item in places.take(5)) {
        if (item is Map<String, dynamic>) {
          final name = item['displayName']?['text'];
          final location = item['location'];
          final lat = location?['latitude'];
          final lon = location?['longitude'];
          stdout.writeln(' - $name @ ($lat,$lon)');
        }
      }
    } else {
      stdout.writeln('No results');
    }
  } catch (e) {
    stderr.writeln('Request failed: $e');
    exit(1);
  }
}

String? _readArg(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index != -1 && index + 1 < args.length) {
    return args[index + 1];
  }
  return null;
}

Future<Map<String, String>> _loadEnv(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('Env file not found: $path');
    exit(1);
  }
  final Map<String, String> values = {};
  for (final line in await file.readAsLines()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || !trimmed.contains('=')) {
      continue;
    }
    final splitIndex = trimmed.indexOf('=');
    final key = trimmed.substring(0, splitIndex).trim();
    final value = trimmed.substring(splitIndex + 1).trim();
    if (key.isNotEmpty) {
      values[key] = value;
    }
  }
  return values;
}
