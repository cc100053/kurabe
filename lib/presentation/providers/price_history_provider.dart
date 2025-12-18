import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/price_entry.dart';
import '../../models/price_record.dart';
import '../../models/product.dart';
import '../../models/shop.dart';
import '../../services/database_helper.dart';
import '../../services/price_logic.dart';

final priceHistoryProvider =
    AsyncNotifierProvider<PriceHistoryNotifier, List<PriceEntry>>(
        PriceHistoryNotifier.new);

class PriceHistoryNotifier extends AsyncNotifier<List<PriceEntry>> {
  late final DatabaseHelper _db;
  late final PriceLogic _priceLogic;

  @override
  Future<List<PriceEntry>> build() async {
    _db = DatabaseHelper.instance;
    _priceLogic = PriceLogic();
    return _fetchRecent();
  }

  Future<void> refresh([String? query]) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchRecent(query));
  }

  Future<List<PriceRecord>> historyForProduct(int productId) {
    return _db.fetchHistoryForProduct(productId);
  }

  Future<String?> addRecord({
    required String productName,
    String? categoryTag,
    String? imagePath,
    required String shopName,
    double? latitude,
    double? longitude,
    required double inputPrice,
    required bool isTaxIncluded,
    required double taxRate,
    DateTime? date,
  }) async {
    final normalizedProduct = productName.trim();
    final normalizedShop = shopName.trim();

    final existingProduct = await _db.getProductByName(normalizedProduct);
    final productId = existingProduct?.id ??
        await _db.insertProduct(
          Product(
            name: normalizedProduct,
            categoryTag: categoryTag,
            imagePath: imagePath,
          ),
        );

    final existingShop = await _db.getShopByName(normalizedShop);
    final shopId = existingShop?.id ??
        await _db.insertShop(
          Shop(
            name: normalizedShop,
            latitude: latitude,
            longitude: longitude,
          ),
        );

    final previousHistory = await _db.fetchHistoryForProduct(productId);
    final finalPrice = _priceLogic.calculateFinalPrice(
      inputPrice,
      isTaxIncluded: isTaxIncluded,
      taxRate: taxRate,
    );

    final record = PriceRecord(
      productId: productId,
      shopId: shopId,
      date: date ?? DateTime.now(),
      inputPrice: inputPrice,
      isTaxIncluded: isTaxIncluded,
      taxRate: taxRate,
      finalPrice: finalPrice,
    );

    await _db.insertPriceRecord(record);
    await refresh();

    final cheaper = _findCheaperAlert(previousHistory, finalPrice);
    if (cheaper != null) {
      final cheaperShop = await _db.getShopById(cheaper.shopId);
      if (cheaperShop != null) {
        return '${cheaper.date.toLocal().toIso8601String().split('T').first}に${cheaperShop.name}でより安い価格（${cheaper.finalPrice.toStringAsFixed(0)}円）が記録されています。';
      }
    }
    return null;
  }

  Future<List<PriceEntry>> _fetchRecent([String? query]) async {
    final rows = await _db.fetchRecentRecords(query: query);
    return rows
        .map(
          (row) => PriceEntry(
            record: PriceRecord.fromMap(row),
            productName: row['product_name'] as String,
            shopName: row['shop_name'] as String,
            categoryTag: row['category_tag'] as String?,
            imagePath: row['image_path'] as String?,
          ),
        )
        .toList();
  }

  PriceRecord? _findCheaperAlert(
      List<PriceRecord> previousHistory, double newPrice) {
    if (previousHistory.isEmpty) return null;
    previousHistory.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
    final cheapest = previousHistory.first;
    return cheapest.finalPrice < newPrice ? cheapest : null;
  }
}
