class PriceRecord {
  PriceRecord({
    this.id,
    required this.productId,
    required this.shopId,
    required this.date,
    required this.inputPrice,
    required this.isTaxIncluded,
    required this.taxRate,
    required this.finalPrice,
  });

  final int? id;
  final int productId;
  final int shopId;
  final DateTime date;
  final double inputPrice;
  final bool isTaxIncluded;
  final double taxRate;
  final double finalPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'shop_id': shopId,
      'date': date.toIso8601String(),
      'input_price': inputPrice,
      'is_tax_included': isTaxIncluded ? 1 : 0,
      'tax_rate': taxRate,
      'final_price': finalPrice,
    };
  }

  factory PriceRecord.fromMap(Map<String, dynamic> map) {
    return PriceRecord(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      shopId: map['shop_id'] as int,
      date: DateTime.parse(map['date'] as String),
      inputPrice: (map['input_price'] as num).toDouble(),
      isTaxIncluded: (map['is_tax_included'] as int) == 1,
      taxRate: (map['tax_rate'] as num).toDouble(),
      finalPrice: (map['final_price'] as num).toDouble(),
    );
  }
}
