import '../../data/models/price_record_model.dart';
import 'price_calculator.dart';

class PriceRecordHelpers {
  PriceRecordHelpers._();

  static const PriceCalculator _calculator = PriceCalculator();
  static const double _epsilon = 1e-6;

  static double? unitPriceFor(PriceRecordModel record) {
    return record.effectiveUnitPrice ??
        _calculator.unitPrice(
          price: record.price,
          quantity: record.quantity,
        );
  }

  static Map<String, double> minUnitPriceByName(
    List<PriceRecordModel> records,
  ) {
    final map = <String, double>{};
    for (final record in records) {
      final unitPrice = unitPriceFor(record);
      if (unitPrice == null) continue;
      final name = _normalizeName(record.productName);
      if (name.isEmpty) continue;
      final current = map[name];
      if (current == null || unitPrice < current) {
        map[name] = unitPrice;
      }
    }
    return map;
  }

  static bool isCheapest(
    PriceRecordModel record,
    Map<String, double> minUnitPriceByName,
  ) {
    final unitPrice = unitPriceFor(record);
    if (unitPrice == null) return false;
    final name = _normalizeName(record.productName);
    if (name.isEmpty) return false;
    final minPrice = minUnitPriceByName[name];
    if (minPrice == null) return false;
    return (unitPrice - minPrice).abs() <= _epsilon;
  }

  static String _normalizeName(String input) {
    return input.trim().toLowerCase();
  }
}
