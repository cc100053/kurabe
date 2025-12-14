import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static bool _userIdColumnMissing = false;
  static bool _taxRateColumnMissing = false;

  bool get isGuest => _client.auth.currentUser?.isAnonymous ?? true;

  Future<String> uploadImage(File imageFile) async {
    final ext = p.extension(imageFile.path);
    final objectPath =
        'price_tags_${DateTime.now().millisecondsSinceEpoch}$ext';
    await _client.storage.from('price_tags').upload(
          objectPath,
          imageFile,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('price_tags').getPublicUrl(objectPath);
  }

  Future<void> saveRecord(Map<String, dynamic> recordData) async {
    final payload = Map<String, dynamic>.from(recordData)
      ..removeWhere((_, value) => value == null);
    final userId = _client.auth.currentUser?.id;
    if (userId != null && !_userIdColumnMissing) {
      payload['user_id'] = userId;
    }
    if (_taxRateColumnMissing) {
      payload.remove('tax_rate');
    }

    final productName = payload['product_name'] as String?;
    final price = (payload['price'] as num?)?.toDouble();
    final quantity = (payload['quantity'] as num?)?.toDouble() ?? 1;
    final unitPrice =
        price != null ? price / (quantity <= 0 ? 1 : quantity) : null;
    final lat = (payload['shop_lat'] as num?)?.toDouble();
    final lng = (payload['shop_lng'] as num?)?.toDouble();

    var isBestPrice = false;
    if (productName != null &&
        productName.trim().isNotEmpty &&
        unitPrice != null &&
        lat != null &&
        lng != null) {
      final nearbyCheapest = await getNearbyCheapest(
        productName: productName,
        lat: lat,
        lng: lng,
        radiusMeters: 2000,
        recentDays: 5,
      );
      if (nearbyCheapest == null) {
        isBestPrice = true;
      } else {
        final otherPrice = (nearbyCheapest['price'] as num?)?.toDouble();
        final otherQuantity =
            (nearbyCheapest['quantity'] as num?)?.toDouble() ?? 1;
        final otherUnitPrice = otherPrice != null
            ? otherPrice / (otherQuantity <= 0 ? 1 : otherQuantity)
            : null;
        if (otherUnitPrice != null && unitPrice <= otherUnitPrice) {
          isBestPrice = true;
        }
      }
    }
    payload['is_best_price'] = isBestPrice;

    try {
      await _client.from('price_records').insert(payload);
    } on PostgrestException catch (e) {
      final missingTaxRate = e.code == 'PGRST204' &&
          (e.message.toLowerCase().contains('tax_rate') ||
              e.message.toLowerCase().contains('tax rate'));
      if (missingTaxRate && payload.containsKey('tax_rate')) {
        _taxRateColumnMissing = true;
        final retryPayload = Map<String, dynamic>.from(payload)
          ..remove('tax_rate');
        await _client.from('price_records').insert(retryPayload);
        return;
      }
      final missingUserId = e.code == 'PGRST204' &&
          (e.message.toLowerCase().contains('user_id') ||
              e.message.toLowerCase().contains('user id'));
      if (missingUserId && payload.containsKey('user_id')) {
        _userIdColumnMissing = true;
        final retryPayload = Map<String, dynamic>.from(payload)
          ..remove('user_id');
        await _client.from('price_records').insert(retryPayload);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getNearbyCheapest({
    required String productName,
    required double lat,
    required double lng,
    int radiusMeters = 2000,
    int recentDays = 5,
  }) async {
    final user = _client.auth.currentUser;
    if (user?.isAnonymous ?? true) return null;
    final result = await _client.rpc(
      'get_nearby_cheapest',
      params: {
        'query_product_name': productName,
        'user_lat': lat,
        'user_lng': lng,
        'search_radius_meters': radiusMeters,
        'recent_days': recentDays,
      },
    );

    if (result == null) return null;
    if (result is List &&
        result.isNotEmpty &&
        result.first is Map<String, dynamic>) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map<String, dynamic>) {
      return result;
    }
    return null;
  }

  Future<List<String>> searchProductNames(String query, {int limit = 3}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    try {
      final result = await _client.rpc(
        'search_products_fuzzy',
        params: {'query_text': trimmed},
      );
      if (result is! List) return [];
      final names = <String>[];
      for (final item in result) {
        String? name;
        if (item is Map && item['product_name'] is String) {
          name = (item['product_name'] as String).trim();
        } else if (item is String) {
          name = item.trim();
        }
        if (name != null && name.isNotEmpty) {
          names.add(name);
        }
      }
      final seen = <String>{};
      final unique = <String>[];
      for (final n in names) {
        if (seen.add(n.toLowerCase())) {
          unique.add(n);
        }
      }
      return unique.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchCommunityPrices(
    String query,
    double? lat,
    double? lng, {
    int limit = 20,
  }) async {
    final user = _client.auth.currentUser;
    if (user?.isAnonymous ?? true) return [];
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // Try RPC first (if location is available) to leverage distance sorting.
    if (lat != null && lng != null) {
      try {
        final result = await _client.rpc(
          'search_community_prices',
          params: {
            'query_text': trimmed,
            'user_lat': lat,
            'user_lng': lng,
            'limit_results': limit,
          },
        );
        if (result is List && result.isNotEmpty) {
          final items = result
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          return _groupCommunityResults(items);
        }
      } catch (_) {
        // Fall back below.
      }
    }

    // Fallback: simple query without location.
    try {
      final List<dynamic> result = await _client
          .from('price_records')
          .select()
          .ilike('product_name', '%$trimmed%')
          .order('price', ascending: true)
          .limit(limit);
      final items = result
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return _groupCommunityResults(items);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyRecordsByCategory(
    String categoryTag,
  ) async {
    final trimmed = categoryTag.trim();
    if (trimmed.isEmpty) return [];
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final List<dynamic> result = await _client
          .from('price_records')
          .select()
          .eq('user_id', userId)
          .eq('category_tag', trimmed)
          .order('created_at', ascending: false);
      return result
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on PostgrestException catch (e) {
      final missingUserIdColumn =
          e.code == '42703' && e.message.toLowerCase().contains('user_id');
      if (missingUserIdColumn) {
        _userIdColumnMissing = true;
        return [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyRecordsByCategory({
    required String categoryTag,
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    final trimmed = categoryTag.trim();
    if (trimmed.isEmpty) return [];
    final user = _client.auth.currentUser;
    if (user?.isAnonymous ?? true) return [];

    try {
      final result = await _client.rpc(
        'get_nearby_records_by_category',
        params: {
          'category_text': trimmed,
          'user_lat': lat,
          'user_lng': lng,
          'radius_meters': radiusMeters,
        },
      );
      if (result is List) {
        return result
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _groupCommunityResults(
    List<Map<String, dynamic>> records,
  ) {
    Map<String, dynamic>? _pickLatest(
      Map<String, dynamic>? a,
      Map<String, dynamic> b,
    ) {
      if (a == null) return b;
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aDate == null && bDate == null) return b;
      if (aDate == null) return b;
      if (bDate == null) return a;
      return bDate.isAfter(aDate) ? b : a;
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final name =
          (record['product_name'] as String?)?.trim().toLowerCase() ?? '';
      final shop = (record['shop_name'] as String?)?.trim().toLowerCase() ?? '';
      final price = (record['price'] as num?)?.toDouble();
      final quantity = (record['quantity'] as num?)?.toDouble() ?? 1;
      final unitPrice = (record['unit_price'] as num?)?.toDouble() ??
          (price != null ? price / (quantity <= 0 ? 1 : quantity) : null);
      final key =
          '$name|$shop|${price?.toStringAsFixed(4) ?? 'na'}|${unitPrice?.toStringAsFixed(6) ?? 'na'}';
      grouped.putIfAbsent(key, () => []).add(record);
    }

    final deduped = <Map<String, dynamic>>[];
    for (final group in grouped.values) {
      final confirmationCount = group.length;
      Map<String, dynamic>? latest;
      for (final record in group) {
        latest = _pickLatest(latest, record);
      }
      final merged = Map<String, dynamic>.from(latest ?? group.first);
      merged['confirmation_count'] = confirmationCount;
      deduped.add(merged);
    }

    int _compareNum(num? a, num? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    deduped.sort((a, b) {
      final unitA = (a['unit_price'] as num?)?.toDouble() ??
          ((a['price'] as num?)?.toDouble() ?? 0);
      final unitB = (b['unit_price'] as num?)?.toDouble() ??
          ((b['price'] as num?)?.toDouble() ?? 0);
      final cmpUnit = _compareNum(unitA, unitB);
      if (cmpUnit != 0) return cmpUnit;
      final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // newest first when unit price ties
    });

    return deduped;
  }
}
