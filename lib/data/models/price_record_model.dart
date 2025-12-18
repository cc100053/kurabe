class PriceRecordPayload {
  const PriceRecordPayload({
    required this.productName,
    required this.price,
    required this.quantity,
    required this.isTaxIncluded,
    this.taxRate,
    this.originalPrice,
    this.priceType,
    this.discountType,
    this.discountValue,
    required this.shopName,
    this.shopLat,
    this.shopLng,
    this.imageUrl,
    this.categoryTag,
  });

  final String productName;
  final double price;
  final int quantity;
  final bool isTaxIncluded;
  final double? taxRate;
  final double? originalPrice;
  final String? priceType;
  final String? discountType;
  final double? discountValue;
  final String shopName;
  final double? shopLat;
  final double? shopLng;
  final String? imageUrl;
  final String? categoryTag;
}

class PriceRecordModel {
  PriceRecordModel({
    this.id,
    required this.productName,
    this.price,
    double? quantity,
    this.originalPrice,
    this.priceType,
    this.discountType,
    this.discountValue,
    this.isTaxIncluded,
    this.taxRate,
    this.shopName,
    this.shopLat,
    this.shopLng,
    this.imageUrl,
    this.categoryTag,
    this.distanceMeters,
    this.isBestPrice,
    this.unit,
    this.unitPrice,
    this.userId,
    this.createdAt,
    this.confirmationCount,
  }) : quantity = quantity ?? 1;

  final int? id;
  final String productName;
  final double? price;
  final double quantity;
  final double? originalPrice;
  final String? priceType;
  final String? discountType;
  final double? discountValue;
  final bool? isTaxIncluded;
  final double? taxRate;
  final String? shopName;
  final double? shopLat;
  final double? shopLng;
  final double? distanceMeters;
  final String? imageUrl;
  final String? categoryTag;
  final bool? isBestPrice;
  final String? unit;
  final double? unitPrice;
  final String? userId;
  final DateTime? createdAt;
  final int? confirmationCount;

  double get normalizedQuantity => quantity <= 0 ? 1 : quantity;

  double? get effectiveUnitPrice => unitPrice;

  PriceRecordModel copyWith({
    int? id,
    String? productName,
    double? price,
    double? quantity,
    double? originalPrice,
    String? priceType,
    String? discountType,
    double? discountValue,
    bool? isTaxIncluded,
    double? taxRate,
    String? shopName,
    double? shopLat,
    double? shopLng,
    double? distanceMeters,
    String? imageUrl,
    String? categoryTag,
    bool? isBestPrice,
    String? unit,
    double? unitPrice,
    String? userId,
    DateTime? createdAt,
    int? confirmationCount,
  }) {
    return PriceRecordModel(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      originalPrice: originalPrice ?? this.originalPrice,
      priceType: priceType ?? this.priceType,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      isTaxIncluded: isTaxIncluded ?? this.isTaxIncluded,
      taxRate: taxRate ?? this.taxRate,
      shopName: shopName ?? this.shopName,
      shopLat: shopLat ?? this.shopLat,
      shopLng: shopLng ?? this.shopLng,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryTag: categoryTag ?? this.categoryTag,
      isBestPrice: isBestPrice ?? this.isBestPrice,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      confirmationCount: confirmationCount ?? this.confirmationCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'original_price': originalPrice,
      'price_type': priceType,
      'discount_type': discountType,
      'discount_value': discountValue,
      'is_tax_included': isTaxIncluded,
      'tax_rate': taxRate,
      'shop_name': shopName,
      'shop_lat': shopLat,
      'shop_lng': shopLng,
      'distance_meters': distanceMeters,
      'image_url': imageUrl,
      'category_tag': categoryTag,
      'is_best_price': isBestPrice,
      'unit': unit,
      'unit_price': unitPrice,
      'user_id': userId,
      'created_at': createdAt?.toIso8601String(),
      'confirmation_count': confirmationCount,
    }..removeWhere((_, value) => value == null);
  }
}
