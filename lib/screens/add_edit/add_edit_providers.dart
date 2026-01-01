import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/config/app_config.dart';
import '../../data/repositories/price_repository.dart';
import '../../domain/price/price_calculator.dart';
import '../../data/models/price_record_model.dart';
import 'dart:async';
import '../../domain/usecases/analyze_price_tag_use_case.dart';
import '../../domain/usecases/save_price_record_use_case.dart';
import '../../services/gemini_service.dart';
import '../../services/google_places_service.dart';
import '../../services/location_service.dart';
import 'add_edit_state.dart';
import 'add_edit_view_model.dart';

const _insightRadiusMeters = 3000;

final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return PriceRepository();
});

final googlePlacesServiceProvider =
    Provider.autoDispose<GooglePlacesService>((ref) {
  final service = GooglePlacesService();
  ref.onDispose(service.dispose);
  return service;
});

final analyzePriceTagUseCaseProvider =
    Provider.autoDispose<AnalyzePriceTagUseCase>((ref) {
  final config = ref.watch(appConfigProvider);
  return AnalyzePriceTagUseCase(
    geminiService: GeminiService(apiKey: config.geminiApiKey),
  );
});

final savePriceRecordUseCaseProvider =
    Provider.autoDispose<SavePriceRecordUseCase>((ref) {
  return SavePriceRecordUseCase(
    repository: ref.watch(priceRepositoryProvider),
  );
});

final addEditViewModelProvider =
    AutoDisposeNotifierProvider<AddEditViewModel, AddEditState>(
  AddEditViewModel.new,
);

final nearbyShopsProvider =
    AutoDisposeFutureProvider.family<List<GooglePlace>, String>(
  (ref, apiKey) async {
    if (apiKey.isEmpty) return const <GooglePlace>[];
    var cancelled = false;
    ref.onDispose(() => cancelled = true);
    final shops =
        await LocationRepository.instance.fetchNearbyShops(apiKey: apiKey);
    if (cancelled) return const <GooglePlace>[];
    if (shops.isEmpty) return const <GooglePlace>[];
    return _prioritizeShops(shops);
  },
);

class ShopPredictionRequest {
  const ShopPredictionRequest({required this.query, required this.apiKey});

  final String query;
  final String apiKey;
}

final shopPredictionsProvider = AutoDisposeFutureProviderFamily<
    List<PlaceAutocompletePrediction>, ShopPredictionRequest>(
  (ref, request) async {
    final query = request.query.trim();
    if (request.apiKey.isEmpty || query.isEmpty) {
      return const <PlaceAutocompletePrediction>[];
    }
    var cancelled = false;
    ref.onDispose(() => cancelled = true);

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (cancelled) return const <PlaceAutocompletePrediction>[];

    final service = ref.watch(googlePlacesServiceProvider);
    final coords = LocationRepository.instance.getFreshLatLng() ??
        await LocationRepository.instance.ensureLocation();
    if (cancelled) return const <PlaceAutocompletePrediction>[];

    final predictions = await service.autocomplete(
      apiKey: request.apiKey,
      input: query,
      latitude: coords?.$1,
      longitude: coords?.$2,
      radiusMeters: _insightRadiusMeters.toDouble(),
      languageCode: 'ja',
    );
    if (cancelled) return const <PlaceAutocompletePrediction>[];
    return _sortPredictions(predictions);
  },
);

class InsightRequest {
  const InsightRequest({
    required this.productName,
    required this.finalTaxedTotal,
    required this.quantity,
    required this.apiKey,
    required this.isPro,
  });

  final String productName;
  final double? finalTaxedTotal;
  final int quantity;
  final String apiKey;
  final bool isPro;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InsightRequest &&
        other.productName == productName &&
        other.finalTaxedTotal == finalTaxedTotal &&
        other.quantity == quantity &&
        other.apiKey == apiKey &&
        other.isPro == isPro;
  }

  @override
  int get hashCode => Object.hash(
        productName,
        finalTaxedTotal,
        quantity,
        apiKey,
        isPro,
      );
}

final communityInsightProvider =
    AutoDisposeFutureProviderFamily<AddEditInsight, InsightRequest>(
  (ref, request) async {
    var cancelled = false;
    ref.onDispose(() => cancelled = true);

    final productName =
        request.productName.replaceAll(RegExp(r'[\s\u3000]+'), '');
    if (productName.isEmpty || request.finalTaxedTotal == null) {
      return AddEditInsight.idle;
    }
    if (request.apiKey.isEmpty) return AddEditInsight.idle;

    // Debounce to avoid rapid refetch while the user is typing.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (cancelled) return AddEditInsight.idle;

    (double, double)? coords;
    try {
      coords = LocationRepository.instance.getFreshLatLng() ??
          await LocationRepository.instance
              .ensureLocation()
              .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      return AddEditInsight.none;
    }
    if (cancelled) return AddEditInsight.idle;
    if (coords == null) return AddEditInsight.none;

    final repository = ref.watch(priceRepositoryProvider);
    const calculator = PriceCalculator();
    final userUnitPrice = calculator.unitPrice(
      price: request.finalTaxedTotal,
      quantity: request.quantity.toDouble(),
    );
    PriceRecordModel? cheapest;
    try {
      cheapest = await repository
          .getNearbyCheapest(
            productName: productName,
            lat: coords.$1,
            lng: coords.$2,
            radiusMeters: _insightRadiusMeters,
          )
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      return AddEditInsight.none;
    }
    if (cancelled) return AddEditInsight.idle;
    if (cheapest == null) {
      if (!request.isPro) {
        try {
          final count = await repository
              .countCommunityPrices(
                productName,
                coords.$1,
                coords.$2,
                limit: 3,
              )
              .timeout(const Duration(seconds: 6));
          if (cancelled) return AddEditInsight.idle;
          if (count > 0) {
            return const AddEditInsight(
              status: InsightStatus.found,
              gated: true,
              gatedMessage: '周辺に記録があります。Proで店舗と価格を表示。',
            );
          }
        } catch (_) {
          return AddEditInsight.none;
        }
      }
      return AddEditInsight.none;
    }

    final nearbyUnitPrice = cheapest.effectiveUnitPrice;
    if (userUnitPrice == null || nearbyUnitPrice == null) {
      if (!request.isPro) {
        return const AddEditInsight(
          status: InsightStatus.none,
          gated: true,
          gatedMessage: '周辺に記録があります。Proで店舗と価格を表示。',
        );
      }
      return AddEditInsight.none;
    }
    final isBest = calculator.isBetterOrEqualUnitPrice(
      candidate: userUnitPrice,
      comparison: nearbyUnitPrice,
    );

    // For non-Pro users, only reveal that a cheaper price exists without store/price details.
    if (!request.isPro) {
      if (isBest) {
        return const AddEditInsight(
          status: InsightStatus.best,
          gated: true,
          gatedMessage: '周辺最安値です。Proで詳細を確認。',
        );
      }
      return const AddEditInsight(
        status: InsightStatus.found,
        gated: true,
        gatedMessage: '周辺に安い店舗があります。Proで店舗と価格を表示。',
      );
    }

    return AddEditInsight(
      status: isBest ? InsightStatus.best : InsightStatus.found,
      price: cheapest.price,
      shop: cheapest.shopName,
      distanceMeters: cheapest.distanceMeters,
    );
  },
);

List<GooglePlace> _prioritizeShops(List<GooglePlace> shops) {
  final sorted = [...shops];
  sorted.sort((a, b) {
    final da = a.distanceMeters ?? double.maxFinite;
    final db = b.distanceMeters ?? double.maxFinite;
    final distCmp = da.compareTo(db);
    if (distCmp != 0) return distCmp;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

List<PlaceAutocompletePrediction> _sortPredictions(
  List<PlaceAutocompletePrediction> predictions,
) {
  final sorted = [...predictions];
  sorted.sort((a, b) {
    final da = a.distanceMeters;
    final db = b.distanceMeters;
    if (da != null && db != null && da != db) {
      return da.compareTo(db);
    }
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;
    return a.primaryText.compareTo(b.primaryText);
  });
  return sorted;
}
