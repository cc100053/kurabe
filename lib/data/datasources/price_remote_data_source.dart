import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class PriceRemoteDataSource {
  PriceRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static bool _userIdColumnMissing = false;
  static bool _taxRateColumnMissing = false;

  bool get isGuest => _client.auth.currentUser?.isAnonymous ?? true;
  String? get currentUserId => _client.auth.currentUser?.id;

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

  Future<void> insertPriceRecord(Map<String, dynamic> payload) async {
    final body = Map<String, dynamic>.from(payload);
    if (_taxRateColumnMissing) {
      body.remove('tax_rate');
    }
    if (_userIdColumnMissing) {
      body.remove('user_id');
    }
    try {
      await _client.from('price_records').insert(body);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      final missingTaxRate =
          e.code == 'PGRST204' && message.contains('tax_rate');
      if (missingTaxRate && body.containsKey('tax_rate')) {
        _taxRateColumnMissing = true;
        final retryPayload = Map<String, dynamic>.from(body)
          ..remove('tax_rate');
        await _client.from('price_records').insert(retryPayload);
        return;
      }
      final missingUserId =
          e.code == 'PGRST204' && message.contains('user_id');
      if (missingUserId && body.containsKey('user_id')) {
        _userIdColumnMissing = true;
        final retryPayload = Map<String, dynamic>.from(body)
          ..remove('user_id');
        await _client.from('price_records').insert(retryPayload);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getNearbyCheapestRaw({
    required String productName,
    required double lat,
    required double lng,
    int radiusMeters = 2000,
    int recentDays = 5,
  }) async {
    try {
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
    } catch (e, stack) {
      debugPrint(
          '[PriceRemoteDataSource] getNearbyCheapest failed lat=$lat lng=$lng radius=$radiusMeters err=$e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchCommunityPricesRaw(
    String query,
    double? lat,
    double? lng, {
    int limit = 20,
  }) async {
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
          return result
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        // Fall back below.
      }
    }

    try {
      final List<dynamic> result = await _client
          .from('price_records')
          .select()
          .ilike('product_name', '%$trimmed%')
          .order('price', ascending: true)
          .limit(limit);
      return result
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchMyPricesRaw(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final userId = currentUserId;
    if (userId == null) return [];
    try {
      final List<dynamic> result = await _client
          .from('price_records')
          .select()
          .eq('user_id', userId)
          .ilike('product_name', '%$trimmed%')
          .order('created_at', ascending: false)
          .limit(limit);
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

  Future<List<Map<String, dynamic>>> getMyRecordsByCategoryRaw(
    String categoryTag,
  ) async {
    final trimmed = categoryTag.trim();
    if (trimmed.isEmpty) return [];
    final userId = currentUserId;
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

  Future<List<Map<String, dynamic>>> getNearbyRecordsByCategoryRaw({
    required String categoryTag,
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    final trimmed = categoryTag.trim();
    if (trimmed.isEmpty) return [];
    if (isGuest) return [];

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

  Future<int> countNearbyCommunityPricesRaw({
    required String query,
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return 0;
    try {
      final result = await _client.rpc(
        'count_nearby_community_prices',
        params: {
          'query_text': trimmed,
          'user_lat': lat,
          'user_lng': lng,
          'search_radius_meters': radiusMeters,
        },
      );
      if (result is int) return result;
      if (result is num) return result.toInt();
      if (result is Map && result['count'] is num) {
        return (result['count'] as num).toInt();
      }
      return 0;
    } catch (e, stack) {
      debugPrint(
          '[PriceRemoteDataSource] count_nearby_community_prices failed: $e');
      debugPrintStack(stackTrace: stack);
      return 0;
    }
  }

  Future<List<dynamic>> searchProductNamesRaw(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    try {
      final result = await _client.rpc(
        'search_products_fuzzy',
        params: {'query_text': trimmed},
      );
      if (result is List && result.isNotEmpty) return result;
    } on PostgrestException catch (e, stack) {
      debugPrint(
          '[PriceRemoteDataSource] search_products_fuzzy rpc failed: ${e.message}');
      debugPrintStack(stackTrace: stack);
    } catch (e, stack) {
      debugPrint(
          '[PriceRemoteDataSource] search_products_fuzzy rpc error: $e');
      debugPrintStack(stackTrace: stack);
    }

    // Fallback: use community search RPC (definer) to fetch names even for guests.
    try {
      final result = await _client.rpc(
        'search_community_prices',
        params: {
          'query_text': trimmed,
          'user_lat': 0,
          'user_lng': 0,
          'limit_results': limit,
        },
      );
      if (result is List && result.isNotEmpty) return result;
    } catch (e, stack) {
      debugPrint(
          '[PriceRemoteDataSource] search_community_prices fallback failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    try {
      final List<dynamic> response = await _client
          .from('price_records')
          .select('product_name')
          .ilike('product_name', '%$trimmed%')
          .order('created_at', ascending: false)
          .limit(limit);
      if (response.isNotEmpty) return response;
    } on PostgrestException catch (e, stack) {
      debugPrint(
          '[PriceRemoteDataSource] fallback product search failed: ${e.message}');
      debugPrintStack(stackTrace: stack);
    } catch (e, stack) {
      debugPrint(
          '[PriceRemoteDataSource] fallback product search error: $e');
      debugPrintStack(stackTrace: stack);
    }
    return [];
  }
}
