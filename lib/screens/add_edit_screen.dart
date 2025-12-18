import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../constants/categories.dart';
import '../constants/category_visuals.dart';
import '../data/config/app_config.dart';
import '../data/models/price_record_model.dart';
import '../data/repositories/price_repository.dart';
import '../domain/price/price_calculator.dart';
import '../main.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import 'smart_camera_screen.dart';

enum _ImageAcquisitionOption { smartCamera, gallery }

enum _InsightState { idle, loading, none, found, best }

enum _DiscountType { none, percentage, fixedAmount }

class AddEditScreen extends ConsumerStatefulWidget {
  const AddEditScreen({super.key});

  @override
  ConsumerState<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends ConsumerState<AddEditScreen> {
  static const String _manualInputSentinel = '__manual_shop_input__';
  static const int _insightRadiusMeters = 3000;

  late final String _placesApiKey;
  bool _isCategorySheetOpen = false;
  final _productController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _discountValueController = TextEditingController();
  final _shopController = TextEditingController();
  String? _selectedCategory;
  String _priceType = 'standard';
  _DiscountType _selectedDiscountType = _DiscountType.none;
  final _shopFocusNode = FocusNode();
  late final GeminiService _geminiService;
  late final GooglePlacesService _placeService;
  late final PriceRepository _priceRepository;
  final PriceCalculator _priceCalculator = const PriceCalculator();

  bool _isTaxIncluded = false;
  double _taxRate = 0.10;
  bool _isSaving = false;
  bool _isSavingDialogVisible = false;
  bool _isFetchingShops = false;
  bool _isAnalyzingImage = false;
  Timer? _insightDebounce;
  _InsightState _insightState = _InsightState.idle;
  List<String> _suggestionChips = [];
  double? _insightPrice;
  String? _insightShop;
  double? _insightDistanceMeters;
  File? _imageFile;
  List<GooglePlace> _nearbyShops = [];
  List<PlaceAutocompletePrediction> _shopPredictions = [];
  double? _selectedShopLat;
  double? _selectedShopLng;
  double? _unitPrice;
  double? _finalTaxedTotal;
  bool _isSearchingShopPredictions = false;
  Timer? _shopSearchDebounce;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appConfigProvider);
    _placesApiKey = config.googlePlacesApiKey ?? '';
    _geminiService = GeminiService(apiKey: config.geminiApiKey);
    _placeService = GooglePlacesService();
    _priceRepository = PriceRepository();
    _productController.addListener(_onNameChanged);
    _hydratePrefetchedShops();
    _selectedCategory = 'その他';
    _isTaxIncluded = false;
    _taxRate = 0.10;
    _applyCategoryTax(_selectedCategory);
    _calculateFinalPrice();
  }

  @override
  void dispose() {
    _productController.dispose();
    _originalPriceController.dispose();
    _quantityController.dispose();
    _discountValueController.dispose();
    _shopController.dispose();
    _shopFocusNode.dispose();
    _placeService.dispose();
    _insightDebounce?.cancel();
    _shopSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _handleImageTap() async {
    if (!mounted) return;
    final option = await _showImageSourceSheet();
    if (option == null) return;
    switch (option) {
      case _ImageAcquisitionOption.smartCamera:
        await _captureWithSmartCamera();
        break;
      case _ImageAcquisitionOption.gallery:
        await _pickImageFromGallery();
        break;
    }
  }

  Future<_ImageAcquisitionOption?> _showImageSourceSheet() {
    return showModalBottomSheet<_ImageAcquisitionOption>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('写真を撮る'),
                subtitle: const Text('スマートガイドを使用'),
                onTap: () =>
                    Navigator.pop(context, _ImageAcquisitionOption.smartCamera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('ギャラリーから選択'),
                onTap: () =>
                    Navigator.pop(context, _ImageAcquisitionOption.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _captureWithSmartCamera() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SmartCameraScreen()),
    );
    if (!mounted || path == null) return;
    await _processImageFile(File(path));
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
    );
    if (picked == null) return;
    try {
      final savedFile = await _persistImage(picked.path);
      await _processImageFile(savedFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('画像の処理に失敗しました: $e')));
    }
  }

  Future<File> _persistImage(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final filename =
        'kurabe_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final savedPath = p.join(directory.path, filename);
    return File(sourcePath).copy(savedPath);
  }

  // TODO: Scanning Logic (Orchestration) - Prepares image and calls GeminiService.
  Future<void> _processImageFile(File file) async {
    setState(() {
      _imageFile = file;
      _originalPriceController.clear();
      _quantityController.text = '1';
      _discountValueController.clear();
      _selectedDiscountType = _DiscountType.none;
      _priceType = 'standard';
      _productController.clear();
      _selectedCategory = 'その他';
      _isTaxIncluded = false;
      _applyCategoryTax(_selectedCategory);
      _isAnalyzingImage = true;
      _setInsightState(_InsightState.idle);
      _suggestionChips = [];
    });
    _calculateFinalPrice();
    File imageToSend = file;
    final compressed = await _compressImage(file);
    if (compressed != null) {
      imageToSend = compressed;
      debugPrint(
        'Gemini用に画像を圧縮: ${file.lengthSync()} bytes -> ${imageToSend.lengthSync()} bytes',
      );
    }
    try {
      final result = await _geminiService.analyzeImage(imageToSend);
      if (!mounted) return;
      setState(() {
        final productName = result['product_name'];
        if (productName is String && productName.trim().isNotEmpty) {
          _productController.text = productName.trim();
          _scheduleInsightLookup(immediate: true);
          _fetchSuggestions(_productController.text);
        }
        final rawPrice = result['raw_price'];
        if (rawPrice is num) {
          _originalPriceController.text = rawPrice.round().toString();
        }
        final discountInfo = result['discount_info'];
        if (discountInfo is Map) {
          final type = discountInfo['type'];
          final value = discountInfo['value'];
          if (type is String) {
            _selectedDiscountType = switch (type.toLowerCase()) {
              'percentage' => _DiscountType.percentage,
              'fixed_amount' => _DiscountType.fixedAmount,
              _ => _DiscountType.none,
            };
          }
          if (value is num) {
            _discountValueController.text = value.toString();
          }
        }
        final priceType = result['price_type'];
        if (priceType is String) {
          final normalized = priceType.toLowerCase();
          if (normalized == 'standard' ||
              normalized == 'promo' ||
              normalized == 'clearance') {
            _priceType = normalized;
          }
        }
        _setCategoryFromString(result['category'] as String?);
      });
      _calculateFinalPrice();
    } catch (e, stack) {
      debugPrint('Gemini解析に失敗しました: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        final message = _friendlyGeminiError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
      }
    }
  }

  String _friendlyGeminiError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('503') ||
        text.contains('unavailable') ||
        text.contains('overloaded')) {
      return 'AIが混み合っています。少し待ってから再試行してください。';
    }
    if (text.contains('api key') || text.contains('gemini_api_key')) {
      return 'Gemini APIキーが設定されていません。.envにGEMINI_API_KEYを設定してください。';
    }
    return 'AIがタグを読み取れませんでした。もう一度お試しください。';
  }

  void _clearSelectedShopCoordinates() {
    if (_selectedShopLat == null && _selectedShopLng == null) return;
    setState(() {
      _selectedShopLat = null;
      _selectedShopLng = null;
    });
  }

  void _onShopChanged(String value) {
    _clearSelectedShopCoordinates();
    _shopSearchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _shopPredictions = []);
      return;
    }
    _shopSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchShopPredictions(value),
    );
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

  Future<void> _fetchShopPredictions(String query) async {
    if (_placesApiKey.isEmpty) return;
    setState(() => _isSearchingShopPredictions = true);
    try {
      final cached = LocationService.instance.getFreshLatLng();
      (double, double)? coords = cached;
      coords ??= await LocationService.instance.ensureLocation(
        apiKey: _placesApiKey,
      );
      final predictions = await _placeService.autocomplete(
        apiKey: _placesApiKey,
        input: query,
        latitude: coords?.$1,
        longitude: coords?.$2,
        radiusMeters: _insightRadiusMeters.toDouble(),
        languageCode: 'ja',
      );
      if (!mounted) return;
      setState(() => _shopPredictions = _sortPredictions(predictions));
    } catch (e, stack) {
      debugPrint('店舗候補の取得に失敗: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('店舗候補の取得に失敗しました。もう一度お試しください。'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingShopPredictions = false);
      }
    }
  }

  Future<void> _onShopPredictionTapped(
    PlaceAutocompletePrediction prediction,
  ) async {
    _shopSearchDebounce?.cancel();
    setState(() => _isSearchingShopPredictions = true);
    try {
      final details = await _placeService.fetchPlaceDetails(
        apiKey: _placesApiKey,
        placeId: prediction.placeId,
        languageCode: 'ja',
      );
      if (!mounted) return;
      setState(() {
        _shopController.text = prediction.primaryText;
        _selectedShopLat = details?.latitude;
        _selectedShopLng = details?.longitude;
        _shopPredictions = [];
      });
      if (details == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置情報を取得できませんでした。')),
        );
      }
    } catch (e, stack) {
      debugPrint('Place詳細取得に失敗: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('店舗の詳細取得に失敗しました。もう一度お試しください。'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingShopPredictions = false);
      }
    }
  }

  void _setCategoryFromString(String? category) {
    if (category == null) return;
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;
    if (kCategories.contains(trimmed)) {
      _selectedCategory = trimmed;
    } else {
      _selectedCategory = 'その他';
    }
    _applyCategoryTax(_selectedCategory);
  }

  Future<void> _hydratePrefetchedShops() async {
    final cached = LocationService.instance.getFreshCachedShops();
    if (cached != null && cached.isNotEmpty) {
      final sorted = _prioritizeShops(cached);
      setState(() {
        _nearbyShops = sorted;
        _shopController.text = sorted.first.name;
        _selectedShopLat = sorted.first.latitude;
        _selectedShopLng = sorted.first.longitude;
        _shopPredictions = [];
      });
      return;
    }
    if (_placesApiKey.isEmpty) return;
    setState(() => _isFetchingShops = true);
    await LocationService.instance.preFetchLocation(apiKey: _placesApiKey);
    if (!mounted) return;
    final fetched = LocationService.instance.getFreshCachedShops();
    if (fetched != null && fetched.isNotEmpty) {
      final sorted = _prioritizeShops(fetched);
      setState(() {
        _nearbyShops = sorted;
        _shopController.text = sorted.first.name;
        _selectedShopLat = sorted.first.latitude;
        _selectedShopLng = sorted.first.longitude;
        _shopPredictions = [];
      });
    }
    if (mounted) {
      setState(() => _isFetchingShops = false);
    }
  }

  Future<File?> _compressImage(File file) async {
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
      debugPrint('画像の圧縮に失敗しました: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  String _normalizeName(String input) {
    return input.replaceAll(RegExp(r'[\s\u3000]+'), '');
  }

  Future<void> _fetchSuggestions(String query) async {
    final normalizedQuery = _normalizeName(query);
    if (normalizedQuery.isEmpty) {
      setState(() => _suggestionChips = []);
      return;
    }
    final suggestions = await _priceRepository.searchProductNames(
      normalizedQuery,
    );
    setState(() {
      final display = <String>[];
      for (final s in suggestions) {
        if (_normalizeName(s).toLowerCase() == normalizedQuery.toLowerCase()) {
          continue;
        }
        display.add(s);
        if (display.length >= 3) break;
      }
      _suggestionChips = display;
    });
  }

  void _onNameChanged() {
    _scheduleInsightLookup();
    _fetchSuggestions(_productController.text);
  }

  void _scheduleInsightLookup({bool immediate = false}) {
    _insightDebounce?.cancel();
    if (immediate) {
      _fetchCommunityInsight();
      return;
    }
    _insightDebounce = Timer(
      const Duration(seconds: 1),
      _fetchCommunityInsight,
    );
  }

  void _setInsightState(
    _InsightState state, {
    double? price,
    String? shop,
    double? distanceMeters,
  }) {
    _insightState = state;
    _insightPrice = price;
    _insightShop = shop;
    _insightDistanceMeters = distanceMeters;
  }

  Future<void> _fetchCommunityInsight() async {
    final productName = _productController.text.trim();
    if (productName.isEmpty) {
      setState(() => _setInsightState(_InsightState.idle));
      return;
    }
    if (_placesApiKey.isEmpty) {
      return;
    }

    setState(() => _setInsightState(_InsightState.loading));
    try {
      final latLng = await LocationService.instance.ensureLocation(
        apiKey: _placesApiKey,
      );
      if (latLng == null) {
        setState(() => _setInsightState(_InsightState.none));
        return;
      }
      final cheapest = await _priceRepository.getNearbyCheapest(
        productName: productName,
        lat: latLng.$1,
        lng: latLng.$2,
        radiusMeters: _insightRadiusMeters,
      );
      if (cheapest == null) {
        setState(() => _setInsightState(_InsightState.none));
        return;
      }
      final price = cheapest.price;
      final nearbyUnitPrice = cheapest.effectiveUnitPrice;
      final shop = cheapest.shopName;
      final distance = cheapest.distanceMeters;

      final currentUnitPrice = _currentComparableUnitPrice();
      // Treat as best only when strictly cheaper (ties are not flagged)
      final isBest = currentUnitPrice != null && nearbyUnitPrice != null
          ? currentUnitPrice < (nearbyUnitPrice - 0.01)
          : false;
      setState(() {
        _setInsightState(
          isBest ? _InsightState.best : _InsightState.found,
          price: price,
          shop: shop,
          distanceMeters: distance,
        );
      });
    } catch (e, stack) {
      debugPrint('コミュニティインサイト取得に失敗しました: $e');
      debugPrintStack(stackTrace: stack);
      setState(() => _setInsightState(_InsightState.none));
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

  Future<void> _showShopSelectionSheet() async {
    if (_nearbyShops.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '店舗の候補がありません。位置情報アイコンをタップするか、手動で入力してください。',
          ),
        ),
      );
      _shopFocusNode.requestFocus();
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text(
                      '店舗を選択',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._nearbyShops.map(
                    (place) => ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(place.name),
                      subtitle: _buildShopSubtitle(place),
                      onTap: () => Navigator.pop(context, place.name),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('手動入力'),
                    onTap: () => Navigator.pop(context, _manualInputSentinel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected == _manualInputSentinel) {
      setState(() {
        _selectedShopLat = null;
        _selectedShopLng = null;
        _shopPredictions = [];
      });
      _shopFocusNode.requestFocus();
      return;
    }
    GooglePlace? chosenPlace;
    for (final place in _nearbyShops) {
      if (place.name == selected) {
        chosenPlace = place;
        break;
      }
    }
    setState(() {
      _shopController.text = selected;
      _selectedShopLat = chosenPlace?.latitude;
      _selectedShopLng = chosenPlace?.longitude;
      _shopPredictions = [];
    });
  }

  Widget? _buildShopSubtitle(GooglePlace place) {
    final parts = <String>[];
    if (place.distanceMeters != null) {
      parts.add('${place.distanceMeters!.toStringAsFixed(0)} m');
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' • '));
  }

  double? _parseCurrency(String input) {
    final raw = input.replaceAll(RegExp(r'[¥,]'), '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  int _parseQuantity() {
    final raw = _quantityController.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  (double, double, double)? _computePricing() {
    final originalPrice = _parseCurrency(_originalPriceController.text);
    if (originalPrice == null) return null;
    final quantity = _parseQuantity();
    final discountValue = _parseCurrency(_discountValueController.text) ?? 0;

    double discounted = originalPrice;
    switch (_selectedDiscountType) {
      case _DiscountType.percentage:
        discounted = originalPrice * (1 - (discountValue / 100));
        break;
      case _DiscountType.fixedAmount:
        discounted = originalPrice - discountValue;
        break;
      case _DiscountType.none:
        discounted = originalPrice;
        break;
    }
    if (discounted < 0) discounted = 0;
    final unitPrice = discounted / quantity;
    final finalTaxedTotal = _isTaxIncluded
        ? discounted
        : (discounted * (1 + _taxRate)).floorToDouble();
    return (discounted, unitPrice, finalTaxedTotal);
  }

  void _calculateFinalPrice() {
    final pricing = _computePricing();
    if (!mounted) return;
    setState(() {
      _unitPrice = pricing?.$2;
      _finalTaxedTotal = pricing?.$3;
    });
    // Refresh community insight when price changes so “最安値” reflects edits.
    _scheduleInsightLookup();
  }

  String _discountTypeToDb(_DiscountType type) {
    switch (type) {
      case _DiscountType.percentage:
        return 'percentage';
      case _DiscountType.fixedAmount:
        return 'fixed_amount';
      case _DiscountType.none:
        return 'none';
    }
  }

  Widget _buildPriceSummary() {
    if (_finalTaxedTotal == null && _unitPrice == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KurabeColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (_finalTaxedTotal != null) ...[
            Text(
              '税込 ¥${_finalTaxedTotal!.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: KurabeColors.primary,
              ),
            ),
          ],
          if (_unitPrice != null && _parseQuantity() > 1) ...[
            const SizedBox(width: 12),
            Text(
              '(@¥${_unitPrice!.toStringAsFixed(0)})',
              style: const TextStyle(
                  fontSize: 13, color: KurabeColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaxControls() {
    return Row(
      children: [
        const Text(
          '税:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 8),
        // Tax Included Toggle
        _buildTaxIncludedToggle(),
        const SizedBox(width: 8),
        // Tax Rate Toggle
        Expanded(
          child: _buildTaxRateToggle(),
        ),
      ],
    );
  }

  Widget _buildTaxIncludedToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isTaxIncluded = !_isTaxIncluded;
        });
        _calculateFinalPrice();
      },
      child: Container(
        width: 100,
        height: 34,
        decoration: BoxDecoration(
          color: KurabeColors.border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Animated sliding background
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: _isTaxIncluded ? 2 : null,
              right: _isTaxIncluded ? null : 2,
              top: 2,
              bottom: 2,
              width: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: KurabeColors.primary,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: KurabeColors.primary.withAlpha(50),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Labels
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            _isTaxIncluded ? FontWeight.w700 : FontWeight.w500,
                        color: _isTaxIncluded
                            ? Colors.white
                            : KurabeColors.textSecondary,
                      ),
                      child: const Text('税込'),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            !_isTaxIncluded ? FontWeight.w700 : FontWeight.w500,
                        color: !_isTaxIncluded
                            ? Colors.white
                            : KurabeColors.textSecondary,
                      ),
                      child: const Text('税抜'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRateToggle() {
    final is8Percent = _taxRate == 0.08;

    return GestureDetector(
      onTap: () {
        setState(() {
          _taxRate = is8Percent ? 0.10 : 0.08;
        });
        _calculateFinalPrice();
      },
      child: Container(
        width: 130,
        height: 34,
        decoration: BoxDecoration(
          color: KurabeColors.border,
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 4) / 2;
            return Stack(
              children: [
                // Animated sliding background
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: is8Percent ? 2 : 2 + itemWidth,
                  top: 2,
                  bottom: 2,
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: is8Percent
                          ? KurabeColors.success
                          : KurabeColors.primary,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: (is8Percent
                                  ? KurabeColors.success
                                  : KurabeColors.primary)
                              .withAlpha(50),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Labels
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                is8Percent ? FontWeight.w700 : FontWeight.w500,
                            color: is8Percent
                                ? Colors.white
                                : KurabeColors.textSecondary,
                          ),
                          child: const Text('8% 軽減'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                !is8Percent ? FontWeight.w700 : FontWeight.w500,
                            color: !is8Percent
                                ? Colors.white
                                : KurabeColors.textSecondary,
                          ),
                          child: const Text('10% 標準'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiscountTypeToggle() {
    final selectedIndex = switch (_selectedDiscountType) {
      _DiscountType.none => 0,
      _DiscountType.percentage => 1,
      _DiscountType.fixedAmount => 2,
    };

    return Container(
      width: 130,
      height: 34,
      decoration: BoxDecoration(
        color: KurabeColors.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 4) / 3;
          return Stack(
            children: [
              // Animated sliding background
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: 2 + (selectedIndex * itemWidth),
                top: 2,
                bottom: 2,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedIndex == 0
                        ? KurabeColors.textSecondary
                        : KurabeColors.accent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: (selectedIndex == 0
                                ? KurabeColors.textSecondary
                                : KurabeColors.accent)
                            .withAlpha(50),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: [
                  _buildDiscountOption('なし', 0, selectedIndex),
                  _buildDiscountOption('%', 1, selectedIndex),
                  _buildDiscountOption('¥', 2, selectedIndex),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiscountOption(String label, int index, int selectedIndex) {
    final isSelected = index == selectedIndex;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedDiscountType = switch (index) {
              1 => _DiscountType.percentage,
              2 => _DiscountType.fixedAmount,
              _ => _DiscountType.none,
            };
            if (_selectedDiscountType == _DiscountType.none) {
              _discountValueController.clear();
            }
          });
          _calculateFinalPrice();
        },
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : KurabeColors.textSecondary,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }

  final GlobalKey _priceTypeDropdownKey = GlobalKey();

  Widget _buildModernPriceTypeDropdown() {
    final priceTypeOptions = [
      (
        value: 'standard',
        label: '通常',
        subtitle: '通常価格',
        icon: PhosphorIcons.tag(PhosphorIconsStyle.fill),
        iconColor: KurabeColors.primary,
      ),
      (
        value: 'promo',
        label: '特価',
        subtitle: 'セール・特売',
        icon: PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
        iconColor: KurabeColors.accent,
      ),
      (
        value: 'clearance',
        label: '見切り',
        subtitle: '在庫処分',
        icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
        iconColor: KurabeColors.error,
      ),
    ];

    final selectedOption = priceTypeOptions.firstWhere(
      (o) => o.value == _priceType,
      orElse: () => priceTypeOptions.first,
    );

    return GestureDetector(
      key: _priceTypeDropdownKey,
      onTap: () => _showPriceTypePopup(priceTypeOptions),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: KurabeColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KurabeColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selectedOption.iconColor.withAlpha(26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                selectedOption.icon,
                size: 14,
                color: selectedOption.iconColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedOption.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KurabeColors.textPrimary,
                ),
              ),
            ),
            Icon(
              PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
              size: 16,
              color: KurabeColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPriceTypePopup(
      List<
              ({
                String value,
                String label,
                String subtitle,
                IconData icon,
                Color iconColor
              })>
          options) async {
    final RenderBox renderBox =
        _priceTypeDropdownKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final screenWidth = MediaQuery.of(context).size.width;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        screenWidth - 200, // Right-align with fixed width
        offset.dy + size.height + 4,
        16, // Right margin
        0,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: KurabeColors.surfaceElevated,
      items: options.map((option) {
        final isSelected = option.value == _priceType;
        return PopupMenuItem<String>(
          value: option.value,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? KurabeColors.primary.withAlpha(20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: option.iconColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    option.icon,
                    size: 18,
                    color: option.iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? KurabeColors.primary
                              : KurabeColors.textPrimary,
                        ),
                      ),
                      Text(
                        option.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KurabeColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: KurabeColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (result != null && result != _priceType) {
      setState(() => _priceType = result);
    }
  }

  Widget _buildInsightCard() {
    if (_insightState == _InsightState.idle) return const SizedBox.shrink();

    IconData icon;
    Color iconColor;
    Color bgColor;
    String title;
    String? subtitle;

    if (_insightState == _InsightState.loading) {
      icon = Icons.search;
      iconColor = KurabeColors.textTertiary;
      bgColor = KurabeColors.divider;
      title = '周辺の価格を検索中...';
    } else if (_insightState == _InsightState.none) {
      icon = Icons.add_circle_outline;
      iconColor = KurabeColors.primary;
      bgColor = KurabeColors.primary.withAlpha(20);
      title = '周辺に記録なし';
      subtitle = 'この商品の最初の投稿者になろう！';
    } else if (_insightState == _InsightState.best) {
      icon = Icons.emoji_events;
      iconColor = Colors.amber.shade700;
      bgColor = Colors.amber.shade100;
      title = '周辺最安値！';
      if (_insightPrice != null && _insightShop != null) {
        final distance = _insightDistanceMeters != null
            ? _formatDistance(_insightDistanceMeters!)
            : '';
        subtitle = '次点: $_insightShop ¥${_insightPrice!.round()} $distance';
      }
    } else {
      // _InsightState.found - there's a cheaper price nearby
      icon = Icons.local_offer;
      iconColor = KurabeColors.success;
      bgColor = KurabeColors.success.withAlpha(20);
      final priceText =
          _insightPrice != null ? '¥${_insightPrice!.round()}' : '';
      final shopText = _insightShop ?? '';
      final distance = _insightDistanceMeters != null
          ? _formatDistance(_insightDistanceMeters!)
          : '';
      title = 'より安い店舗あり';
      subtitle = '$shopText $priceText $distance'.trim();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KurabeColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: KurabeColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km 先';
    }
    return '${meters.toStringAsFixed(0)} m 先';
  }

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

  Future<void> _fetchLocation() async {
    if (_placesApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google Places APIキーがありません。.envにGOOGLE_PLACES_API_KEYを設定してください。',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isFetchingShops = true);
    await LocationService.instance.preFetchLocation(
      apiKey: _placesApiKey,
      forceRefresh: true,
    );
    if (!mounted) return;
    final cached = LocationService.instance.getFreshCachedShops();
    if (cached == null || cached.isEmpty) {
      setState(() {
        _isFetchingShops = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('近くに店舗が見つかりませんでした。')));
      return;
    }
    final sorted = _prioritizeShops(cached);
    setState(() {
      _nearbyShops = sorted;
      _shopController.text = sorted.first.name;
      _selectedShopLat = sorted.first.latitude;
      _selectedShopLng = sorted.first.longitude;
      _shopPredictions = [];
      _isFetchingShops = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('最寄りの店舗を選択しました: ${_nearbyShops.first.name}'),
      ),
    );
  }

  void _showSavingDialog() {
    _isSavingDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('保存中...'),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isSavingDialogVisible = false;
    });
  }

  void _applyCategoryTax(String? category) {
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
    final newRate = isFood ? 0.08 : 0.10;
    if (_taxRate != newRate) {
      if (mounted) {
        setState(() {
          _taxRate = newRate;
        });
      } else {
        _taxRate = newRate;
      }
      _calculateFinalPrice();
    }
  }

  double? _currentComparableUnitPrice() {
    final pricing = _computePricing();
    if (pricing == null) return null;
    final quantity = _parseQuantity();
    final taxedTotal = pricing.$3;
    return _priceCalculator.unitPrice(
      price: taxedTotal,
      quantity: quantity.toDouble(),
    );
  }

  void _hideSavingDialog() {
    if (_isSavingDialogVisible &&
        Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _isSavingDialogVisible = false;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final product = _productController.text.trim();
    final normalizedProduct = _normalizeName(product);
    final shop = _shopController.text.trim();
    final originalPrice = _parseCurrency(_originalPriceController.text);
    final pricing = _computePricing();
    final finalTaxedTotal = pricing?.$3;
    final discountValue = _parseCurrency(_discountValueController.text) ?? 0;
    final quantity = _parseQuantity();

    if (product.isEmpty ||
        shop.isEmpty ||
        originalPrice == null ||
        finalTaxedTotal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('商品名、店舗名、元の価格は必須です。'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    _showSavingDialog();

    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _priceRepository.uploadImage(_imageFile!);
      }

      final categoryToSave =
          (_selectedCategory != null && _selectedCategory!.trim().isNotEmpty
              ? _selectedCategory!
              : 'その他');

      final payload = PriceRecordPayload(
        productName: normalizedProduct,
        price: finalTaxedTotal,
        originalPrice: originalPrice,
        quantity: quantity,
        priceType: _priceType,
        discountType: _discountTypeToDb(_selectedDiscountType),
        discountValue: discountValue,
        isTaxIncluded: _isTaxIncluded,
        taxRate: _taxRate,
        shopName: shop,
        shopLat: _selectedShopLat,
        shopLng: _selectedShopLng,
        imageUrl: imageUrl,
        categoryTag: categoryToSave,
      );

      await _priceRepository.saveRecord(payload);

      if (!mounted) return;
      _hideSavingDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録を保存しました。')),
      );
      Navigator.pop(context, '記録を保存しました。');
    } catch (e) {
      if (!mounted) return;
      _hideSavingDialog();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('記録の保存に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('記録を追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleImageTap,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 160,
                        height: 180,
                        child: _imageFile != null
                            ? Image.file(_imageFile!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 36,
                                      color: Colors.black54,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'スキャン',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    if (_isAnalyzingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildInsightCard(),
            const SizedBox(height: 10),
            TextField(
              controller: _productController,
              decoration: const InputDecoration(labelText: '商品名'),
            ),
            if (_suggestionChips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestionChips
                    .map(
                      (s) => ActionChip(
                        label: Text('✨ $s'),
                        backgroundColor: Colors.green.shade100,
                        onPressed: () {
                          _productController.text = s;
                          setState(() => _suggestionChips = []);
                          _scheduleInsightLookup(immediate: true);
                          _fetchSuggestions(s);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _originalPriceController,
              decoration: const InputDecoration(
                labelText: '元の価格',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateFinalPrice(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: '数量',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateFinalPrice(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernPriceTypeDropdown(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildTaxControls(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '割引:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                // Modern discount toggle
                _buildDiscountTypeToggle(),
                if (_selectedDiscountType != _DiscountType.none) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _discountValueController,
                      decoration: const InputDecoration(
                        labelText: '値',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateFinalPrice(),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _buildPriceSummary(),
            const SizedBox(height: 8),
            _buildCategoryPicker(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shopController,
                    focusNode: _shopFocusNode,
                    onChanged: _onShopChanged,
                    decoration: InputDecoration(
                      labelText: '店舗名',
                      suffixIcon: _isFetchingShops
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.store_mall_directory),
                              tooltip: '近くの店舗を選択',
                              onPressed: _showShopSelectionSheet,
                            ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isFetchingShops ? null : _fetchLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Google Placesから自動入力',
                ),
              ],
            ),
            if (_shopPredictions.isNotEmpty || _isSearchingShopPredictions) ...[
              const SizedBox(height: 8),
              _buildShopPredictionList(),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopPredictionList() {
    final predictions = _shopPredictions.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: KurabeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KurabeColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  KurabeColors.primary.withAlpha(15),
                  KurabeColors.primary.withAlpha(5),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: KurabeColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: KurabeColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '候補店舗',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KurabeColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_isSearchingShopPredictions)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(KurabeColors.primary),
                    ),
                  )
                else
                  Text(
                    '${predictions.length}件',
                    style: const TextStyle(
                      fontSize: 12,
                      color: KurabeColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),

          // Predictions list
          if (predictions.isNotEmpty)
            ...predictions.asMap().entries.map((entry) {
              final index = entry.key;
              final prediction = entry.value;
              final isLast = index == predictions.length - 1;

              // Build subtitle parts
              final subtitleParts = <String>[];
              if (prediction.secondaryText != null &&
                  prediction.secondaryText!.isNotEmpty) {
                subtitleParts.add(prediction.secondaryText!);
              }

              // Distance indicator
              final distanceText = prediction.distanceMeters != null
                  ? _formatDistance(prediction.distanceMeters!)
                  : null;

              // Distance color based on proximity
              Color distanceColor = KurabeColors.textTertiary;
              Color distanceBgColor = KurabeColors.divider;
              if (prediction.distanceMeters != null) {
                if (prediction.distanceMeters! < 300) {
                  distanceColor = KurabeColors.success;
                  distanceBgColor = KurabeColors.success.withAlpha(20);
                } else if (prediction.distanceMeters! < 1000) {
                  distanceColor = KurabeColors.primary;
                  distanceBgColor = KurabeColors.primary.withAlpha(20);
                }
              }

              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onShopPredictionTapped(prediction),
                      borderRadius: isLast
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(16))
                          : BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Store icon badge
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: KurabeColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                PhosphorIcons.storefront(
                                    PhosphorIconsStyle.fill),
                                size: 20,
                                color: KurabeColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prediction.primaryText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: KurabeColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (subtitleParts.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        subtitleParts.join(' • '),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: KurabeColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Distance badge
                            if (distanceText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: distanceBgColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  distanceText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: distanceColor,
                                  ),
                                ),
                              ),
                            ],

                            // Arrow
                            const SizedBox(width: 4),
                            Icon(
                              PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                              size: 14,
                              color: KurabeColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 68),
                      child: Container(
                        height: 1,
                        color: KurabeColors.divider,
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    final selected = _selectedCategory ?? 'その他';
    final visual = kCategoryVisuals[selected];
    final icon =
        visual?.icon ?? PhosphorIcons.tagSimple(PhosphorIconsStyle.bold);

    return GestureDetector(
      onTap: _showCategorySheet,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'カテゴリ',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (visual?.color ?? KurabeColors.surface).withAlpha(200),
              ),
              child: Icon(
                icon,
                size: 14,
                color: KurabeColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              _isCategorySheetOpen
                  ? PhosphorIcons.caretUp(PhosphorIconsStyle.bold)
                  : PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
              color: KurabeColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategorySheet() async {
    setState(() => _isCategorySheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        final viewPadding = MediaQuery.of(context).viewPadding;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: viewInsets.bottom + viewPadding.bottom + 12,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: KurabeColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'カテゴリを選択',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: _buildCategoryGridBody(
                          onSelect: (name) {
                            setState(() {
                              _selectedCategory = name;
                              _applyCategoryTax(name);
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) {
      setState(() => _isCategorySheetOpen = false);
    }
  }

  Widget _buildCategoryGridBody({required void Function(String) onSelect}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kCategories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final name = kCategories[index];
        final visual = kCategoryVisuals[name];
        final icon =
            visual?.icon ?? PhosphorIcons.tagSimple(PhosphorIconsStyle.bold);
        final isSelected = _selectedCategory == name;

        return GestureDetector(
          onTap: () => onSelect(name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: visual != null
                  ? LinearGradient(
                      colors: [
                        visual.color,
                        visual.gradientEnd,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        KurabeColors.surface,
                        KurabeColors.surfaceElevated,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? KurabeColors.primary : KurabeColors.border,
                width: isSelected ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(220),
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: KurabeColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w700,
                          color: KurabeColors.textPrimary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        PhosphorIcons.check(PhosphorIconsStyle.bold),
                        size: 14,
                        color: KurabeColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
