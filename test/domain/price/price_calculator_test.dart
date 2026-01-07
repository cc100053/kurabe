import 'package:flutter_test/flutter_test.dart';
import 'package:kurabe/domain/price/price_calculator.dart';

void main() {
  const calculator = PriceCalculator();

  group('normalizedQuantity', () {
    test('returns 1 for null', () {
      expect(calculator.normalizedQuantity(null), 1);
    });

    test('returns 1 for zero', () {
      expect(calculator.normalizedQuantity(0), 1);
    });

    test('returns 1 for negative', () {
      expect(calculator.normalizedQuantity(-5), 1);
    });

    test('returns same value for positive', () {
      expect(calculator.normalizedQuantity(3), 3);
    });
  });

  group('unitPrice', () {
    test('calculates correctly', () {
      expect(calculator.unitPrice(price: 300, quantity: 3), 100);
    });

    test('returns null for null price', () {
      expect(calculator.unitPrice(price: null, quantity: 2), isNull);
    });

    test('uses quantity 1 when quantity is null', () {
      expect(calculator.unitPrice(price: 100, quantity: null), 100);
    });

    test('uses quantity 1 when quantity is zero', () {
      expect(calculator.unitPrice(price: 100, quantity: 0), 100);
    });
  });

  group('isBetterOrEqualUnitPrice', () {
    test('returns true when candidate is lower', () {
      expect(
        calculator.isBetterOrEqualUnitPrice(candidate: 90, comparison: 100),
        isTrue,
      );
    });

    test('returns true when candidate equals comparison', () {
      expect(
        calculator.isBetterOrEqualUnitPrice(candidate: 100, comparison: 100),
        isTrue,
      );
    });

    test('returns false when candidate is higher', () {
      expect(
        calculator.isBetterOrEqualUnitPrice(candidate: 110, comparison: 100),
        isFalse,
      );
    });

    test('returns false when candidate is null', () {
      expect(
        calculator.isBetterOrEqualUnitPrice(candidate: null, comparison: 100),
        isFalse,
      );
    });

    test('returns true when comparison is null', () {
      expect(
        calculator.isBetterOrEqualUnitPrice(candidate: 100, comparison: null),
        isTrue,
      );
    });
  });

  group('compareUnitPrices', () {
    test('returns 0 when both null', () {
      expect(calculator.compareUnitPrices(null, null), 0);
    });

    test('returns 1 when first is null', () {
      expect(calculator.compareUnitPrices(null, 100), 1);
    });

    test('returns -1 when second is null', () {
      expect(calculator.compareUnitPrices(100, null), -1);
    });

    test('returns 0 when equal', () {
      expect(calculator.compareUnitPrices(100, 100), 0);
    });

    test('returns -1 when first is smaller', () {
      expect(calculator.compareUnitPrices(90, 100), -1);
    });

    test('returns 1 when first is larger', () {
      expect(calculator.compareUnitPrices(110, 100), 1);
    });
  });

  group('tax conversions', () {
    test('taxIncludedFromExcluded floors correctly (10%)', () {
      expect(
        calculator.taxIncludedFromExcluded(priceExcludingTax: 100, taxRate: 0.10),
        110,
      );
      expect(
        calculator.taxIncludedFromExcluded(priceExcludingTax: 101, taxRate: 0.10),
        111,
      );
    });

    test('taxExcludedFromIncluded ceils to preserve round-trip (10%)', () {
      final excluded = calculator.taxExcludedFromIncluded(
        priceIncludingTax: 111,
        taxRate: 0.10,
      );
      expect(excluded, 101);
      expect(
        calculator.taxIncludedFromExcluded(
          priceExcludingTax: excluded,
          taxRate: 0.10,
        ),
        111,
      );
    });

    test('taxExcludedFromIncluded ceils to preserve round-trip (8%)', () {
      final excluded = calculator.taxExcludedFromIncluded(
        priceIncludingTax: 108,
        taxRate: 0.08,
      );
      expect(excluded, 100);
      expect(
        calculator.taxIncludedFromExcluded(
          priceExcludingTax: excluded,
          taxRate: 0.08,
        ),
        108,
      );
    });

    test('returns null when price is null', () {
      expect(
        calculator.taxIncludedFromExcluded(priceExcludingTax: null, taxRate: 0.10),
        isNull,
      );
      expect(
        calculator.taxExcludedFromIncluded(priceIncludingTax: null, taxRate: 0.10),
        isNull,
      );
    });
  });
}
