import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/gemini_service.dart';
import '../price/discount_type.dart';

class PriceScanResult {
  const PriceScanResult({
    this.productName,
    this.rawPrice,
    this.discountType = DiscountType.none,
    this.discountValue,
    this.priceType,
    this.category,
  });

  final String? productName;
  final double? rawPrice;
  final DiscountType discountType;
  final double? discountValue;
  final String? priceType;
  final String? category;
}

class AnalyzePriceTagUseCase {
  AnalyzePriceTagUseCase({
    required GeminiService geminiService,
    ImageCompressor? imageCompressor,
  })  : _geminiService = geminiService,
        _imageCompressor = imageCompressor ?? ImageCompressor();

  final GeminiService _geminiService;
  final ImageCompressor _imageCompressor;

  Future<PriceScanResult> call(File imageFile) async {
    File imageForGemini = imageFile;
    final compressed = await _imageCompressor.compress(imageFile);
    if (compressed != null) {
      imageForGemini = compressed;
      debugPrint(
        '[AnalyzePriceTag] 圧縮済み ${imageFile.lengthSync()} -> ${imageForGemini.lengthSync()} bytes',
      );
    }
    final parsed = await _geminiService.analyzeImage(imageForGemini);
    return _mapParsedResult(parsed);
  }

  PriceScanResult _mapParsedResult(Map<String, dynamic> parsed) {
    final productName = (parsed['product_name'] as String?)?.trim();
    final rawPrice = parsed['raw_price'];
    final discountInfo = parsed['discount_info'];
    final priceType = parsed['price_type'] as String?;
    final category = parsed['category'] as String?;

    DiscountType discountType = DiscountType.none;
    double? discountValue;

    if (discountInfo is Map) {
      final type = (discountInfo['type'] as String?)?.toLowerCase();
      final value = discountInfo['value'];
      if (type == 'percentage') {
        discountType = DiscountType.percentage;
      } else if (type == 'fixed_amount') {
        discountType = DiscountType.fixedAmount;
      }
      if (value is num) {
        discountValue = value.toDouble();
      }
    }

    return PriceScanResult(
      productName: productName?.isNotEmpty == true ? productName : null,
      rawPrice: rawPrice is num ? rawPrice.toDouble() : null,
      discountType: discountType,
      discountValue: discountValue,
      priceType: _normalizePriceType(priceType),
      category: category,
    );
  }

  String? _normalizePriceType(String? raw) {
    if (raw == null) return null;
    final normalized = raw.toLowerCase();
    if (normalized == 'promo' || normalized == 'clearance') return normalized;
    return 'standard';
  }
}

class ImageCompressor {
  Future<File?> compress(File file) async {
    try {
      final dimensions = await _readImageDimensions(file);
      int targetWidth = 1024;
      int targetHeight = 1024;
      if (dimensions != null) {
        final width = dimensions.$1.toDouble();
        final height = dimensions.$2.toDouble();
        final maxSide = width > height ? width : height;
        if (maxSide > 1024) {
          final scale = 1024 / maxSide;
          targetWidth = (width * scale).round();
          targetHeight = (height * scale).round();
        } else {
          targetWidth = width.round();
          targetHeight = height.round();
        }
      }

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 70,
        minWidth: targetWidth,
        minHeight: targetHeight,
        format: CompressFormat.jpeg,
      );
      if (compressedBytes == null) return null;
      final tmpDir = await getTemporaryDirectory();
      final output = File(
        p.join(
          tmpDir.path,
          'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      await output.writeAsBytes(compressedBytes, flush: true);
      return output;
    } catch (e, stack) {
      debugPrint('画像の圧縮に失敗: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<(int, int)?> _readImageDimensions(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) => completer.complete(img));
      final image = await completer.future;
      final dims = (image.width, image.height);
      image.dispose();
      return dims;
    } catch (_) {
      return null;
    }
  }
}
