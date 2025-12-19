import 'dart:io';

import '../price/discount_type.dart';
import '../price/price_calculator.dart';
import '../../data/models/price_record_model.dart';
import '../../data/repositories/price_repository.dart';

class SavePriceRecordInput {
  const SavePriceRecordInput({
    required this.productName,
    required this.shopName,
    required this.originalPriceText,
    required this.quantityText,
    required this.discountValueText,
    required this.discountType,
    required this.isTaxIncluded,
    required this.taxRate,
    required this.priceType,
    required this.category,
    this.imageFile,
    this.shopLat,
    this.shopLng,
  });

  final String productName;
  final String shopName;
  final String originalPriceText;
  final String quantityText;
  final String discountValueText;
  final DiscountType discountType;
  final bool isTaxIncluded;
  final double taxRate;
  final String priceType;
  final String category;
  final File? imageFile;
  final double? shopLat;
  final double? shopLng;
}

class SavePriceRecordUseCase {
  SavePriceRecordUseCase({
    required PriceRepository repository,
    PriceCalculator? priceCalculator,
  })  : _repository = repository,
        _calculator = priceCalculator ?? const PriceCalculator();

  final PriceRepository _repository;
  final PriceCalculator _calculator;

  Future<void> call(SavePriceRecordInput input) async {
    final product = input.productName.trim();
    final shop = input.shopName.trim();
    final originalPrice = _parseCurrency(input.originalPriceText);
    final quantity = _parseQuantity(input.quantityText);
    final discountValue = _parseCurrency(input.discountValueText) ?? 0;

    if (product.isEmpty || shop.isEmpty || originalPrice == null) {
      throw StateError('商品名、店舗名、元の価格は必須です。');
    }

    final pricing = _computePricing(
      originalPrice: originalPrice,
      quantity: quantity,
      discountType: input.discountType,
      discountValue: discountValue,
      isTaxIncluded: input.isTaxIncluded,
      taxRate: input.taxRate,
    );
    if (pricing.finalTaxedTotal == null) {
      throw StateError('価格の計算に失敗しました。値を確認してください。');
    }

    String? imageUrl;
    if (input.imageFile != null) {
      imageUrl = await _repository.uploadImage(input.imageFile!);
    }

    final payload = PriceRecordPayload(
      productName: _normalizeName(product),
      price: pricing.finalTaxedTotal!,
      originalPrice: originalPrice,
      quantity: quantity,
      priceType: _normalizePriceType(input.priceType),
      discountType: _discountTypeToDb(input.discountType),
      discountValue: discountValue,
      isTaxIncluded: input.isTaxIncluded,
      taxRate: input.taxRate,
      shopName: shop,
      shopLat: input.shopLat,
      shopLng: input.shopLng,
      imageUrl: imageUrl,
      categoryTag: input.category.trim().isEmpty ? 'その他' : input.category,
    );

    await _repository.saveRecord(payload);
  }

  _ComputedPricing _computePricing({
    required double originalPrice,
    required int quantity,
    required DiscountType discountType,
    required double discountValue,
    required bool isTaxIncluded,
    required double taxRate,
  }) {
    double discounted = originalPrice;
    switch (discountType) {
      case DiscountType.percentage:
        discounted = originalPrice * (1 - (discountValue / 100));
        break;
      case DiscountType.fixedAmount:
        discounted = originalPrice - discountValue;
        break;
      case DiscountType.none:
        discounted = originalPrice;
        break;
    }
    if (discounted < 0) discounted = 0;

    final unitPrice =
        _calculator.unitPrice(price: discounted, quantity: quantity.toDouble());
    final finalTaxedTotal = isTaxIncluded
        ? discounted
        : (discounted * (1 + taxRate)).floorToDouble();

    return _ComputedPricing(
      discounted: discounted,
      unitPrice: unitPrice,
      finalTaxedTotal: finalTaxedTotal,
    );
  }

  String _discountTypeToDb(DiscountType type) {
    switch (type) {
      case DiscountType.percentage:
        return 'percentage';
      case DiscountType.fixedAmount:
        return 'fixed_amount';
      case DiscountType.none:
        return 'none';
    }
  }

  int _parseQuantity(String input) {
    final parsed = int.tryParse(input.trim());
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  double? _parseCurrency(String input) {
    final raw = input.replaceAll(RegExp(r'[¥,]'), '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String _normalizeName(String input) {
    return input.replaceAll(RegExp(r'[\s\u3000]+'), '');
  }

  String _normalizePriceType(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized == 'promo' || normalized == 'clearance') return normalized;
    return 'standard';
  }
}

class _ComputedPricing {
  _ComputedPricing({
    required this.discounted,
    required this.unitPrice,
    required this.finalTaxedTotal,
  });

  final double discounted;
  final double? unitPrice;
  final double? finalTaxedTotal;
}
