class PriceCalculator {
  const PriceCalculator();

  static const double _epsilon = 1e-6;
  static const double _taxEpsilon = 1e-9;

  /// Returns a normalized quantity to avoid division by zero.
  double normalizedQuantity(double? quantity) {
    if (quantity == null || quantity <= 0) return 1;
    return quantity;
  }

  /// Converts a tax-exclusive price to a tax-inclusive price using floor rounding
  /// (typical for Japanese POS price display).
  double? taxIncludedFromExcluded({
    required double? priceExcludingTax,
    required double taxRate,
  }) {
    if (priceExcludingTax == null) return null;
    return (priceExcludingTax * (1 + taxRate)).floorToDouble();
  }

  /// Converts a tax-inclusive price to a tax-exclusive price.
  ///
  /// This uses ceil rounding so that when the returned value is converted back
  /// via [taxIncludedFromExcluded] it matches the original tax-inclusive input
  /// under floor rounding.
  double? taxExcludedFromIncluded({
    required double? priceIncludingTax,
    required double taxRate,
  }) {
    if (priceIncludingTax == null) return null;
    final raw = priceIncludingTax / (1 + taxRate);
    return (raw - _taxEpsilon).ceilToDouble();
  }

  /// Computes unit price (price per quantity). Returns null when price is null.
  double? unitPrice({required double? price, double? quantity}) {
    if (price == null) return null;
    final normalizedQty = normalizedQuantity(quantity);
    return price / normalizedQty;
  }

  /// Returns true when the candidate unit price is better (lower) than or equal
  /// to the comparison price within a small epsilon.
  bool isBetterOrEqualUnitPrice({
    required double? candidate,
    required double? comparison,
  }) {
    if (candidate == null) return false;
    if (comparison == null) return true;
    return candidate <= comparison + _epsilon;
  }

  /// Compares nullable unit prices with nulls treated as the worst case.
  int compareUnitPrices(double? a, double? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final diff = a - b;
    if (diff.abs() <= _epsilon) return 0;
    return diff < 0 ? -1 : 1;
  }
}
