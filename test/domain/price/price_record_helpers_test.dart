import 'package:flutter_test/flutter_test.dart';
import 'package:kurabe/data/models/price_record_model.dart';
import 'package:kurabe/domain/price/price_record_helpers.dart';

void main() {
  group('minUnitPriceByName', () {
    test('returns empty map for empty list', () {
      final result = PriceRecordHelpers.minUnitPriceByName([]);
      expect(result, isEmpty);
    });

    test('finds minimum unit price per product', () {
      final records = [
        _createRecord(productName: 'りんご', price: 100, quantity: 1),
        _createRecord(productName: 'りんご', price: 180, quantity: 2), // 90/個
        _createRecord(productName: 'みかん', price: 200, quantity: 1),
      ];

      final result = PriceRecordHelpers.minUnitPriceByName(records);

      expect(result['りんご'], 90);
      expect(result['みかん'], 200);
    });

    test('normalizes product names to lowercase', () {
      final records = [
        _createRecord(productName: 'Apple', price: 100, quantity: 1),
        _createRecord(productName: 'apple', price: 80, quantity: 1),
      ];

      final result = PriceRecordHelpers.minUnitPriceByName(records);

      expect(result.length, 1);
      expect(result['apple'], 80);
    });
  });

  group('isCheapest', () {
    test('returns true for cheapest record', () {
      final record = _createRecord(productName: 'りんご', price: 90, quantity: 1);
      final minPrices = {'りんご': 90.0};

      expect(PriceRecordHelpers.isCheapest(record, minPrices), isTrue);
    });

    test('returns false for non-cheapest record', () {
      final record = _createRecord(productName: 'りんご', price: 100, quantity: 1);
      final minPrices = {'りんご': 90.0};

      expect(PriceRecordHelpers.isCheapest(record, minPrices), isFalse);
    });

    test('returns false for empty map', () {
      final record = _createRecord(productName: 'りんご', price: 100, quantity: 1);

      expect(PriceRecordHelpers.isCheapest(record, {}), isFalse);
    });

    test('returns false when product not in map', () {
      final record = _createRecord(productName: 'りんご', price: 100, quantity: 1);
      final minPrices = {'みかん': 90.0};

      expect(PriceRecordHelpers.isCheapest(record, minPrices), isFalse);
    });
  });

  group('unitPriceFor', () {
    test('uses unitPrice when available', () {
      final record = PriceRecordModel(
        productName: 'りんご',
        price: 100,
        quantity: 2,
        unitPrice: 45,
      );

      expect(PriceRecordHelpers.unitPriceFor(record), 45);
    });

    test('calculates from price/quantity when unitPrice is null', () {
      final record = _createRecord(productName: 'りんご', price: 100, quantity: 2);

      expect(PriceRecordHelpers.unitPriceFor(record), 50);
    });
  });
}

PriceRecordModel _createRecord({
  required String productName,
  required double price,
  required double quantity,
}) {
  return PriceRecordModel(
    productName: productName,
    price: price,
    quantity: quantity,
  );
}
