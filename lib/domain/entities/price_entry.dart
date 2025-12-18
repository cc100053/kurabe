import '../../models/price_record.dart';

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
