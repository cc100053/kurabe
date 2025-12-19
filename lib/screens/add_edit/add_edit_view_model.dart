import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/categories.dart';
import '../../domain/price/discount_type.dart';
import '../../domain/usecases/analyze_price_tag_use_case.dart';
import '../../domain/usecases/save_price_record_use_case.dart';
import '../../services/google_places_service.dart';
import '../../services/location_service.dart';
import 'add_edit_providers.dart';
import 'add_edit_state.dart';

class AddEditViewModel extends AutoDisposeNotifier<AddEditState> {
  Timer? _suggestionDebounce;
  int _suggestionRequestId = 0;

  @override
  AddEditState build() {
    ref.onDispose(() {
      _suggestionDebounce?.cancel();
    });
    return const AddEditState();
  }

  void updateProductName(String value) {
    state = state.copyWith(productName: value);
    _recalculatePrice();
    _debounceSuggestions();
    
  }

  void updateOriginalPrice(String value) {
    state = state.copyWith(originalPrice: value);
    _recalculatePrice();
    
  }

  void updateQuantity(String value) {
    state = state.copyWith(quantity: value.isEmpty ? '1' : value);
    _recalculatePrice();
    
  }

  void updateDiscountValue(String value) {
    state = state.copyWith(discountValue: value);
    _recalculatePrice();
    
  }

  void setDiscountType(DiscountType type) {
    state = state.copyWith(
      discountType: type,
      discountValue: type == DiscountType.none ? '' : state.discountValue,
    );
    _recalculatePrice();
    
  }

  void setPriceType(String value) {
    state = state.copyWith(priceType: _normalizePriceType(value));
    
  }

  void toggleTaxIncluded() {
    state = state.copyWith(isTaxIncluded: !state.isTaxIncluded);
    _recalculatePrice();
    
  }

  void setTaxRate(double rate) {
    state = state.copyWith(taxRate: rate);
    _recalculatePrice();
    
  }

  void setCategory(String category) {
    final normalized = _normalizeCategory(category);
    final taxRate = _taxRateForCategory(normalized);
    state = state.copyWith(category: normalized, taxRate: taxRate);
    _recalculatePrice();
    
  }

  void setShopName(String value) {
    state = state.copyWith(
      shopName: value,
      selectedShopLat: null,
      selectedShopLng: null,
    );
  }

  void applyNearbyShops(List<GooglePlace> shops) {
    if (shops.isEmpty) return;
    if (state.shopName.trim().isNotEmpty) {
      state = state.copyWith(nearbyShops: shops);
      return;
    }
    final first = shops.first;
    state = state.copyWith(
      nearbyShops: shops,
      shopName: first.name,
      selectedShopLat: first.latitude,
      selectedShopLng: first.longitude,
    );
  }

  void selectNearbyShop(GooglePlace place) {
    state = state.copyWith(
      shopName: place.name,
      selectedShopLat: place.latitude,
      selectedShopLng: place.longitude,
    );
  }

  Future<void> selectPrediction(
    PlaceAutocompletePrediction prediction,
    String apiKey,
  ) async {
    final service = ref.read(googlePlacesServiceProvider);
    final details = await service.fetchPlaceDetails(
      apiKey: apiKey,
      placeId: prediction.placeId,
      languageCode: 'ja',
    );
    state = state.copyWith(
      shopName: prediction.primaryText,
      selectedShopLat: details?.latitude,
      selectedShopLng: details?.longitude,
    );
  }

  Future<PriceScanResult> analyzeImage(File file) async {
    final useCase = ref.read(analyzePriceTagUseCaseProvider);
    state = state.copyWith(
      imageFile: file,
      originalPrice: '',
      quantity: '1',
      discountValue: '',
      discountType: DiscountType.none,
      priceType: 'standard',
      productName: '',
      category: 'その他',
      isTaxIncluded: false,
      taxRate: _taxRateForCategory('その他'),
      isAnalyzing: true,
      suggestionChips: const [],
    );
    _recalculatePrice();
    try {
      final result = await useCase(file);
      _applyScanResult(result);
      state = state.copyWith(isAnalyzing: false);
      return result;
    } catch (e) {
      state = state.copyWith(isAnalyzing: false);
      rethrow;
    }
  }

  Future<void> save() async {
    if (state.isSaving) return;
    final useCase = ref.read(savePriceRecordUseCaseProvider);
    double? shopLat = state.selectedShopLat;
    double? shopLng = state.selectedShopLng;
    if (shopLat == null || shopLng == null) {
      try {
        final loc = await LocationRepository.instance.ensurePosition(
          cacheMaxAge: const Duration(minutes: 5),
        );
        final pos = loc.position;
        if (pos != null) {
          shopLat = pos.latitude;
          shopLng = pos.longitude;
        }
      } catch (_) {
        // Best-effort; continue without location.
      }
    }
    state = state.copyWith(isSaving: true);
    try {
      await useCase(
        SavePriceRecordInput(
          productName: state.productName,
          shopName: state.shopName,
          originalPriceText: state.originalPrice,
          quantityText: state.quantity,
          discountValueText: state.discountValue,
          discountType: state.discountType,
          isTaxIncluded: state.isTaxIncluded,
          taxRate: state.taxRate,
          priceType: state.priceType,
          category: state.category,
          imageFile: state.imageFile,
          shopLat: shopLat,
          shopLng: shopLng,
        ),
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> _fetchSuggestions() async {
    final normalizedQuery = _normalizeName(state.productName);
    if (normalizedQuery.isEmpty) {
      state = state.copyWith(suggestionChips: const []);
      return;
    }
    final repository = ref.read(priceRepositoryProvider);
    final requestId = ++_suggestionRequestId;
    final suggestions = await repository.searchProductNames(normalizedQuery);
    if (requestId != _suggestionRequestId) return;
    final display = <String>[];
    for (final s in suggestions) {
      if (_normalizeName(s).toLowerCase() == normalizedQuery.toLowerCase())
        continue;
      display.add(s);
      if (display.length >= 3) break;
    }
    state = state.copyWith(suggestionChips: display);
  }

  void _debounceSuggestions() {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(
      const Duration(milliseconds: 250),
      _fetchSuggestions,
    );
  }

  void clearSuggestions() {
    _suggestionDebounce?.cancel();
    state = state.copyWith(suggestionChips: const []);
  }

  void _applyScanResult(PriceScanResult result) {
    final category = _normalizeCategory(result.category ?? state.category);
    final taxRate = _taxRateForCategory(category);
    state = state.copyWith(
      productName: result.productName ?? state.productName,
      originalPrice: result.rawPrice != null
          ? result.rawPrice!.round().toString()
          : state.originalPrice,
      discountType: result.discountType,
      discountValue: result.discountValue?.toString() ?? state.discountValue,
      priceType: _normalizePriceType(result.priceType ?? state.priceType),
      category: category,
      taxRate: taxRate,
      isTaxIncluded: false,
    );
    _recalculatePrice();
    _fetchSuggestions();
    
  }

  void _recalculatePrice() {
    final originalPrice = _parseCurrency(state.originalPrice);
    final discountValue = _parseCurrency(state.discountValue) ?? 0;
    final quantity = _parseQuantity(state.quantity);

    double? finalTaxedTotal;
    double? unitPrice;
    if (originalPrice != null) {
      double discounted = originalPrice;
      switch (state.discountType) {
        case DiscountType.percentage:
          discounted = originalPrice * (1 - (discountValue / 100));
          break;
        case DiscountType.fixedAmount:
          discounted = originalPrice - discountValue;
          break;
        case DiscountType.none:
          discounted = originalPrice;
          break;
      }
      if (discounted < 0) discounted = 0;
      unitPrice = discounted / quantity;
      finalTaxedTotal = state.isTaxIncluded
          ? discounted
          : (discounted * (1 + state.taxRate)).floorToDouble();
    }

    state = state.copyWith(
      unitPrice: unitPrice,
      finalTaxedTotal: finalTaxedTotal,
    );
    
  }

  double? _parseCurrency(String input) {
    final raw = input.replaceAll(RegExp(r'[¥,]'), '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  int _parseQuantity(String input) {
    final parsed = int.tryParse(input.trim());
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  String _normalizeName(String input) {
    return input.replaceAll(RegExp(r'[\s\u3000]+'), '');
  }

  String _normalizeCategory(String category) {
    if (kCategories.contains(category)) return category;
    return 'その他';
  }

  String _normalizePriceType(String? raw) {
    final value = (raw ?? '').toLowerCase();
    if (value == 'promo' || value == 'clearance') return value;
    return 'standard';
  }

  double _taxRateForCategory(String? category) {
    const foodCategories = {
      '野菜',
      '果物',
      '精肉',
      '鮮魚',
      '惣菜',
      '卵',
      '乳製品',
      '豆腐・納豆・麺',
      'パン',
      '米・穀物',
      '調味料',
      'インスタント',
      '飲料',
      'お菓子',
      '冷凍食品',
    };
    final isFood = category != null && foodCategories.contains(category);
    return isFood ? 0.08 : 0.10;
  }
}
