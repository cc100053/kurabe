import 'dart:io';

import '../../domain/price/price_calculator.dart';
import '../datasources/price_remote_data_source.dart';
import '../mappers/price_record_mapper.dart';
import '../models/price_record_model.dart';

class PriceRepository {
  PriceRepository({
    PriceRemoteDataSource? remoteDataSource,
    PriceRecordMapper? mapper,
    PriceCalculator? priceCalculator,
  })  : _remote = remoteDataSource ?? PriceRemoteDataSource(),
        _calculator = priceCalculator ?? const PriceCalculator(),
        _mapper = mapper ??
            PriceRecordMapper(
              calculator: priceCalculator ?? const PriceCalculator(),
            );

  final PriceRemoteDataSource _remote;
  final PriceRecordMapper _mapper;
  final PriceCalculator _calculator;

  bool get isGuest => _remote.isGuest;

  Future<String> uploadImage(File imageFile) {
    return _remote.uploadImage(imageFile);
  }

  Future<void> saveRecord(PriceRecordPayload payload) async {
    final productName = payload.productName.trim();
    final unitPrice =
        _calculator.unitPrice(
      price: payload.price,
      quantity: payload.quantity.toDouble(),
    );

    var isBestPrice = false;
    if (productName.isNotEmpty &&
        unitPrice != null &&
        payload.shopLat != null &&
        payload.shopLng != null) {
      final nearbyCheapest = await getNearbyCheapest(
        productName: productName,
        lat: payload.shopLat!,
        lng: payload.shopLng!,
        radiusMeters: 2000,
        recentDays: 5,
      );
      final comparisonUnit = nearbyCheapest?.effectiveUnitPrice;
      isBestPrice = _calculator.isBetterOrEqualUnitPrice(
        candidate: unitPrice,
        comparison: comparisonUnit,
      );
    }

    final insertMap = _mapper.toInsertMap(
      payload,
      userId: _remote.currentUserId,
    )..['is_best_price'] = isBestPrice;

    await _remote.insertPriceRecord(insertMap);
  }

  Future<PriceRecordModel?> getNearbyCheapest({
    required String productName,
    required double lat,
    required double lng,
    int radiusMeters = 2000,
    int recentDays = 5,
  }) async {
    if (productName.trim().isEmpty) return null;
    final raw = await _remote.getNearbyCheapestRaw(
      productName: productName,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      recentDays: recentDays,
    );
    if (raw == null) return null;
    return _mapper.fromMap(raw);
  }

  Future<List<String>> searchProductNames(String query, {int limit = 3}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final raw = await _remote.searchProductNamesRaw(trimmed);
    final names = <String>[];
    for (final item in raw) {
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
  }

  Future<List<PriceRecordModel>> searchCommunityPrices(
    String query,
    double? lat,
    double? lng, {
    int limit = 20,
  }) async {
    if (isGuest) return [];
    final raw = await _remote.searchCommunityPricesRaw(
      query,
      lat,
      lng,
      limit: limit,
    );
    final mapped = raw.map(_mapper.fromMap).toList();
    return _dedupeCommunityResults(mapped);
  }

  Future<List<PriceRecordModel>> searchMyPrices(
    String query, {
    int limit = 20,
  }) async {
    final raw = await _remote.searchMyPricesRaw(query, limit: limit);
    return raw.map(_mapper.fromMap).toList();
  }

  Future<int> countCommunityPrices(
    String query,
    double? lat,
    double? lng, {
    int limit = 20,
  }) async {
    final results = await searchCommunityPrices(
      query,
      lat,
      lng,
      limit: limit,
    );
    return results.length;
  }

  Future<int> countCheaperCommunityPrices({
    required String productName,
    required double userUnitPrice,
    double? lat,
    double? lng,
    int limit = 20,
  }) async {
    final results = await searchCommunityPrices(
      productName,
      lat,
      lng,
      limit: limit,
    );
    var count = 0;
    for (final record in results) {
      final price = record.effectiveUnitPrice;
      if (price != null && price + 1e-6 < userUnitPrice) {
        count++;
      }
    }
    return count;
  }

  Future<List<PriceRecordModel>> getMyRecordsByCategory(
    String categoryTag,
  ) async {
    final raw = await _remote.getMyRecordsByCategoryRaw(categoryTag);
    return raw.map(_mapper.fromMap).toList();
  }

  Future<List<PriceRecordModel>> getNearbyRecordsByCategory({
    required String categoryTag,
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    final raw = await _remote.getNearbyRecordsByCategoryRaw(
      categoryTag: categoryTag,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
    );
    return raw.map(_mapper.fromMap).toList();
  }

  List<PriceRecordModel> _dedupeCommunityResults(
    List<PriceRecordModel> records,
  ) {
    PriceRecordModel? pickLatest(
      PriceRecordModel? a,
      PriceRecordModel b,
    ) {
      if (a == null) return b;
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return b;
      if (aDate == null) return b;
      if (bDate == null) return a;
      return bDate.isAfter(aDate) ? b : a;
    }

    final grouped = <String, List<PriceRecordModel>>{};
    for (final record in records) {
      final unitPrice = record.effectiveUnitPrice;
      final key =
          '${record.productName.toLowerCase()}|${(record.shopName ?? '').toLowerCase()}|${record.price?.toStringAsFixed(4) ?? 'na'}|${unitPrice?.toStringAsFixed(6) ?? 'na'}';
      grouped.putIfAbsent(key, () => []).add(record);
    }

    final deduped = <PriceRecordModel>[];
    for (final group in grouped.values) {
      final confirmationCount = group.length;
      PriceRecordModel? latest;
      for (final record in group) {
        latest = pickLatest(latest, record);
      }
      final merged = (latest ?? group.first)
          .copyWith(confirmationCount: confirmationCount);
      deduped.add(merged);
    }

    deduped.sort((a, b) {
      final cmpUnit =
          _calculator.compareUnitPrices(a.effectiveUnitPrice, b.effectiveUnitPrice);
      if (cmpUnit != 0) return cmpUnit;
      final dateA = a.createdAt;
      final dateB = b.createdAt;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return deduped;
  }
}
