import 'dart:math';

/// Encapsulates OCR-derived pricing details.
class PriceParseResult {
  PriceParseResult({
    this.detectedPrice,
    required this.isTaxIncluded,
    required this.taxRate,
    this.detectedKeyword,
  });

  final double? detectedPrice;
  final bool isTaxIncluded;
  final double taxRate;
  final String? detectedKeyword;
}

class PriceLogic {
  // Tax hints in Japanese price tags.
  static const _includedKeywords = ['税込'];
  static const _excludedKeywords = ['税抜', '本体', '+税'];

  /// Picks a tax rate based on the category. Food defaults to 8%, otherwise 10%.
  double determineTaxRate(String? categoryTag) {
    final normalized = categoryTag?.toLowerCase() ?? '';
    if (normalized.contains('food') || normalized.contains('drink') ||
        normalized.contains('meat') || normalized.contains('vegetable')) {
      return 0.08;
    }
    return 0.10;
  }

  /// Calculates final 税込 price. If the detected price is 税抜, tax is applied.
  double calculateFinalPrice(double inputPrice, {required bool isTaxIncluded, required double taxRate}) {
    if (isTaxIncluded) {
      return inputPrice;
    }
    return (inputPrice * (1 + taxRate)).roundToDouble();
  }

  /// Parse OCR text to locate a yen amount and infer whether it is 税抜 or 税込.
  ///
  /// The logic looks for:
  /// - Line-level pairing: pick numbers on the same line as 税込/税抜 markers.
  /// - Prefer numbers with 円 on the line; otherwise fall back to the largest yen-looking number.
  /// - If no keyword is found, assume 税込 to avoid double-taxing and let the user toggle if needed.
  PriceParseResult parseOcrText(String text, {String? categoryTag}) {
    final sanitized = text.replaceAll(',', '').replaceAll('¥', '');
    final lines = sanitized.split('\n');
    final numberRegex = RegExp(r'(\d{2,6}(?:\.\d+)?)円?');

    double? detectedPrice;
    bool? detectedIsIncluded;
    String? detectedKeyword;

    // Pass 1: look for numbers on lines with explicit tax keywords.
    for (final line in lines) {
      final keyword = _keywordForLine(line);
      if (keyword == null) continue;
      final matches = numberRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final withYen = matches
          .where((m) => (m.group(0) ?? '').contains('円'))
          .map((m) => _parseAmount(m.group(0)))
          .whereType<double>()
          .toList();
      final candidates = withYen.isNotEmpty
          ? withYen
          : matches.map((m) => _parseAmount(m.group(1))).whereType<double>().toList();
      if (candidates.isNotEmpty) {
        detectedPrice = candidates.reduce(max);
        detectedIsIncluded = _includedKeywords.contains(keyword);
        detectedKeyword = keyword;
        break;
      }
    }

    // Pass 2: no keyword lines; prefer numbers with 円 anywhere.
    if (detectedPrice == null) {
      final yenMatches = numberRegex.allMatches(sanitized).toList();
      final withYen = yenMatches
          .where((m) => (m.group(0) ?? '').contains('円'))
          .map((m) => _parseAmount(m.group(0)))
          .whereType<double>()
          .toList();
      if (withYen.isNotEmpty) {
        detectedPrice = withYen.reduce(max);
      } else {
        final prices = yenMatches.map((m) => _parseAmount(m.group(1))).whereType<double>().toList();
        if (prices.isNotEmpty) {
          detectedPrice = prices.reduce(max);
        }
      }
    }

    // Default to 税込 when no keyword found to avoid double-taxing; user can toggle.
    final isIncluded = detectedIsIncluded ?? true;
    final taxRate = determineTaxRate(categoryTag);

    final roundedPrice = detectedPrice?.roundToDouble();

    return PriceParseResult(
      detectedPrice: roundedPrice,
      isTaxIncluded: isIncluded,
      taxRate: taxRate,
      detectedKeyword: detectedKeyword,
    );
  }

  double? _parseAmount(String? raw) {
    if (raw == null) return null;
    final normalized = raw.replaceAll('円', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _keywordForLine(String line) {
    final lower = line.toLowerCase();
    for (final k in _includedKeywords) {
      if (lower.contains(k)) return k;
    }
    for (final k in _excludedKeywords) {
      if (lower.contains(k)) return k;
    }
    return null;
  }
}
