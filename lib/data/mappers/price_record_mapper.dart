import '../../domain/price/price_calculator.dart';
import '../models/price_record_model.dart';

class PriceRecordMapper {
  PriceRecordMapper({PriceCalculator? calculator})
      : _calculator = calculator ?? const PriceCalculator();

  final PriceCalculator _calculator;

  PriceRecordModel fromMap(Map<String, dynamic> map) {
    final price = (map['price'] as num?)?.toDouble();
    final rawQuantity = (map['quantity'] as num?)?.toDouble();
    final createdRaw = map['created_at'];
    DateTime? createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw);
    } else if (createdRaw is DateTime) {
      createdAt = createdRaw;
    }

    final unitPrice = (map['unit_price'] as num?)?.toDouble() ??
        _calculator.unitPrice(price: price, quantity: rawQuantity);

    final rawTaxIncluded = map['is_tax_included'];
    bool? isTaxIncluded;
    if (rawTaxIncluded is bool) {
      isTaxIncluded = rawTaxIncluded;
    } else if (rawTaxIncluded is num) {
      isTaxIncluded = rawTaxIncluded.toInt() == 1;
    }

    return PriceRecordModel(
      id: map['id'] as int?,
      productName: (map['product_name'] as String? ?? '').trim(),
      price: price,
      quantity: _calculator.normalizedQuantity(rawQuantity),
      originalPrice: (map['original_price'] as num?)?.toDouble(),
      priceType: map['price_type'] as String?,
      discountType: map['discount_type'] as String?,
      discountValue: (map['discount_value'] as num?)?.toDouble(),
      isTaxIncluded: isTaxIncluded,
      taxRate: (map['tax_rate'] as num?)?.toDouble(),
      shopName: map['shop_name'] as String?,
      shopLat: (map['shop_lat'] as num?)?.toDouble(),
      shopLng: (map['shop_lng'] as num?)?.toDouble(),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      imageUrl: map['image_url'] as String?,
      categoryTag: map['category_tag'] as String?,
      isBestPrice: map['is_best_price'] as bool?,
      unit: map['unit'] as String?,
      unitPrice: unitPrice,
      userId: map['user_id'] as String?,
      createdAt: createdAt?.toLocal(),
      confirmationCount: (map['confirmation_count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toInsertMap(
    PriceRecordPayload payload, {
    String? userId,
    bool includeTaxRate = true,
  }) {
    final map = {
      'product_name': payload.productName,
      'price': payload.price,
      'quantity': payload.quantity,
      'original_price': payload.originalPrice,
      'price_type': payload.priceType,
      'discount_type': payload.discountType,
      'discount_value': payload.discountValue,
      'is_tax_included': payload.isTaxIncluded,
      'tax_rate': payload.taxRate,
      'shop_name': payload.shopName,
      'shop_lat': payload.shopLat,
      'shop_lng': payload.shopLng,
      'image_url': payload.imageUrl,
      'category_tag': payload.categoryTag,
      'user_id': userId,
    };
    if (!includeTaxRate) {
      map.remove('tax_rate');
    }
    map.removeWhere((_, value) => value == null);
    return map;
  }
}
