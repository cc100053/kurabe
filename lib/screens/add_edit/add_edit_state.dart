import 'dart:io';

import '../../domain/price/discount_type.dart';
import '../../services/google_places_service.dart';

enum InsightStatus { idle, none, found, best }

class AddEditInsight {
  const AddEditInsight({
    required this.status,
    this.price,
    this.shop,
    this.distanceMeters,
    this.gated = false,
    this.gatedMessage,
  });

  final InsightStatus status;
  final double? price;
  final String? shop;
  final double? distanceMeters;
  final bool gated;
  final String? gatedMessage;

  static const idle = AddEditInsight(status: InsightStatus.idle);
  static const none = AddEditInsight(status: InsightStatus.none);
}

class AddEditState {
  const AddEditState({
    this.imageFile,
    this.productName = '',
    this.shopName = '',
    this.originalPrice = '',
    this.taxExcludedPrice = '',
    this.taxIncludedPrice = '',
    this.quantity = '1',
    this.discountType = DiscountType.none,
    this.discountValue = '',
    this.priceType = 'standard',
    this.category = 'その他',
    this.isTaxIncluded = false,
    this.taxRate = 0.10,
    this.isAnalyzing = false,
    this.isSaving = false,
    this.suggestionChips = const [],
    this.nearbyShops = const [],
    this.selectedShopLat,
    this.selectedShopLng,
    this.unitPrice,
    this.finalTaxedTotal,
  });

  final File? imageFile;
  final String productName;
  final String shopName;
  final String originalPrice;
  final String taxExcludedPrice;
  final String taxIncludedPrice;
  final String quantity;
  final DiscountType discountType;
  final String discountValue;
  final String priceType;
  final String category;
  final bool isTaxIncluded;
  final double taxRate;
  final bool isAnalyzing;
  final bool isSaving;
  final List<String> suggestionChips;
  final List<GooglePlace> nearbyShops;
  final double? selectedShopLat;
  final double? selectedShopLng;
  final double? unitPrice;
  final double? finalTaxedTotal;

  AddEditState copyWith({
    File? imageFile,
    String? productName,
    String? shopName,
    String? originalPrice,
    String? taxExcludedPrice,
    String? taxIncludedPrice,
    String? quantity,
    DiscountType? discountType,
    String? discountValue,
    String? priceType,
    String? category,
    bool? isTaxIncluded,
    double? taxRate,
    bool? isAnalyzing,
    bool? isSaving,
    List<String>? suggestionChips,
    List<GooglePlace>? nearbyShops,
    double? selectedShopLat,
    double? selectedShopLng,
    double? unitPrice,
    double? finalTaxedTotal,
  }) {
    return AddEditState(
      imageFile: imageFile ?? this.imageFile,
      productName: productName ?? this.productName,
      shopName: shopName ?? this.shopName,
      originalPrice: originalPrice ?? this.originalPrice,
      taxExcludedPrice: taxExcludedPrice ?? this.taxExcludedPrice,
      taxIncludedPrice: taxIncludedPrice ?? this.taxIncludedPrice,
      quantity: quantity ?? this.quantity,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      priceType: priceType ?? this.priceType,
      category: category ?? this.category,
      isTaxIncluded: isTaxIncluded ?? this.isTaxIncluded,
      taxRate: taxRate ?? this.taxRate,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isSaving: isSaving ?? this.isSaving,
      suggestionChips: suggestionChips ?? this.suggestionChips,
      nearbyShops: nearbyShops ?? this.nearbyShops,
      selectedShopLat: selectedShopLat ?? this.selectedShopLat,
      selectedShopLng: selectedShopLng ?? this.selectedShopLng,
      unitPrice: unitPrice ?? this.unitPrice,
      finalTaxedTotal: finalTaxedTotal ?? this.finalTaxedTotal,
    );
  }
}
