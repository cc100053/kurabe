import 'package:flutter/material.dart';

import '../models/price_record.dart';
import '../models/product.dart';
import '../models/shop.dart';
import '../services/database_helper.dart';
import '../services/price_logic.dart';

class PriceEntry {
  PriceEntry({
    required this.record,
    required this.productName,
    required this.shopName,
    this.categoryTag,
    this.imagePath,
  });

  final PriceRecord record;
  final String productName;
  final String shopName;
  final String? categoryTag;
  final String? imagePath;
}

class AppState extends ChangeNotifier {
  AppState({DatabaseHelper? dbHelper, PriceLogic? priceLogic})
      : _db = dbHelper ?? DatabaseHelper.instance,
        _priceLogic = priceLogic ?? PriceLogic();

  final DatabaseHelper _db;
  final PriceLogic _priceLogic;

  final List<PriceEntry> _recent = [];
  bool _initialized = false;

  List<PriceEntry> get recent => List.unmodifiable(_recent);
  bool get initialized => _initialized;

  Future<void> init() async {
    await refresh();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh([String? query]) async {
    final rows = await _db.fetchRecentRecords(query: query);
    _recent
      ..clear()
      ..addAll(rows.map((row) {
        return PriceEntry(
          record: PriceRecord.fromMap(row),
          productName: row['product_name'] as String,
          shopName: row['shop_name'] as String,
          categoryTag: row['category_tag'] as String?,
          imagePath: row['image_path'] as String?,
        );
      }));
    notifyListeners();
  }

  Future<List<PriceRecord>> historyForProduct(int productId) async {
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
              imagePath: imagePath),
        );

    final existingShop = await _db.getShopByName(normalizedShop);
    final shopId = existingShop?.id ??
        await _db.insertShop(
          Shop(name: normalizedShop, latitude: latitude, longitude: longitude),
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

  PriceRecord? _findCheaperAlert(
      List<PriceRecord> previousHistory, double newPrice) {
    if (previousHistory.isEmpty) return null;
    previousHistory.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
    final cheapest = previousHistory.first;
    return cheapest.finalPrice < newPrice ? cheapest : null;
  }
}
