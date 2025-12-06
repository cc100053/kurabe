import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/categories.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import '../services/supabase_service.dart';
import 'smart_camera_screen.dart';

enum _ImageAcquisitionOption { smartCamera, gallery }

enum _InsightState { idle, loading, none, found, best }

enum _DiscountType { none, percentage, fixedAmount }

class AddEditScreen extends StatefulWidget {
  const AddEditScreen({super.key});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  static const String _manualInputSentinel = '__manual_shop_input__';
  static final String _placesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';

  final _productController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _discountValueController = TextEditingController();
  final _shopController = TextEditingController();
  String? _selectedCategory;
  String _priceType = 'standard';
  _DiscountType _selectedDiscountType = _DiscountType.none;
  final _shopFocusNode = FocusNode();
  final GeminiService _geminiService = GeminiService();
  final GooglePlacesService _placeService = GooglePlacesService();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isTaxIncluded = true;
  final double _taxRate = 0.08;
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
  double? _selectedShopLat;
  double? _selectedShopLng;
  double? _unitPrice;
  double? _finalTaxedTotal;

  @override
  void initState() {
    super.initState();
    _productController.addListener(_onNameChanged);
    _hydratePrefetchedShops();
    _selectedCategory = 'その他';
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
      _isTaxIncluded = true;
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
        final quantity = result['quantity'];
        if (quantity is num && quantity > 0) {
          _quantityController.text = quantity.round().toString();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AIがタグを読み取れませんでした')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
      }
    }
  }

  void _clearSelectedShopCoordinates() {
    if (_selectedShopLat == null && _selectedShopLng == null) return;
    setState(() {
      _selectedShopLat = null;
      _selectedShopLng = null;
    });
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
    final suggestions = await _supabaseService.searchProductNames(
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
      final cheapest = await _supabaseService.getNearbyCheapest(
        productName: productName,
        lat: latLng.$1,
        lng: latLng.$2,
      );
      if (cheapest == null) {
        setState(() => _setInsightState(_InsightState.none));
        return;
      }
      final price = (cheapest['price'] as num?)?.toDouble();
      final quantity = (cheapest['quantity'] as num?)?.toDouble() ?? 1;
      final nearbyUnitPrice =
          price != null ? price / (quantity <= 0 ? 1 : quantity) : null;
      final shop = cheapest['shop_name'] as String?;
      final distance = (cheapest['distance_meters'] as num?)?.toDouble();

      final currentUnitPrice = _unitPrice ?? _computePricing()?.$2;
      final isBest = currentUnitPrice != null && nearbyUnitPrice != null
          ? currentUnitPrice <= nearbyUnitPrice
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
    final finalTaxedTotal = (discounted * (1 + _taxRate)).floorToDouble();
    return (discounted, unitPrice, finalTaxedTotal);
  }

  void _calculateFinalPrice() {
    final pricing = _computePricing();
    if (!mounted) return;
    setState(() {
      _unitPrice = pricing?.$2;
      _finalTaxedTotal = pricing?.$3;
    });
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
    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_finalTaxedTotal != null) ...[
              const Text(
                '最終合計（税込）',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '¥${_finalTaxedTotal!.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (_unitPrice != null)
              Text(
                '1個あたり ¥${_unitPrice!.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard() {
    if (_insightState == _InsightState.idle) return const SizedBox.shrink();
    Color bg;
    String text;
    if (_insightState == _InsightState.loading) {
      bg = Colors.grey.shade200;
      text = 'コミュニティ価格を確認中...';
    } else if (_insightState == _InsightState.none) {
      bg = Colors.grey.shade200;
      text = '近くに最近のデータがありません。最初の記録者になりましょう！';
    } else if (_insightState == _InsightState.best) {
      bg = Colors.amber.shade200;
      text = '付近で最安値を見つけました！';
      if (_insightPrice != null && _insightShop != null) {
        text =
            '付近で最安値を見つけました！(¥${_insightPrice!.round()} • $_insightShop)';
      }
    } else {
      bg = Colors.green.shade200;
      final priceText = _insightPrice != null
          ? '¥${_insightPrice!.round()}'
          : 'より安い価格';
      final shopText = _insightShop ?? '近くの店舗';
      final distanceText = _insightDistanceMeters != null
          ? ' (${_formatDistance(_insightDistanceMeters!)})'
          : '';
      text = 'より安い価格を発見！$shopTextで$priceText$distanceText';
    }
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.insights, color: Colors.black54),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
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

    if (product.isEmpty || shop.isEmpty || originalPrice == null ||
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
        imageUrl = await _supabaseService.uploadImage(_imageFile!);
      }

      final categoryToSave =
          (_selectedCategory != null && _selectedCategory!.trim().isNotEmpty
          ? _selectedCategory!
          : 'その他');

      await _supabaseService.saveRecord({
        'product_name': normalizedProduct,
        'price': finalTaxedTotal,
        'original_price': originalPrice,
        'quantity': quantity,
        'price_type': _priceType,
        'discount_type': _discountTypeToDb(_selectedDiscountType),
        'discount_value': discountValue,
        'is_tax_included': _isTaxIncluded,
        'shop_name': shop,
        'shop_lat': _selectedShopLat,
        'shop_lng': _selectedShopLng,
        'image_url': imageUrl,
        'category_tag': categoryToSave,
      });

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
        padding: const EdgeInsets.all(16),
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
                        width: 200,
                        height: 280,
                        child: _imageFile != null
                            ? Image.file(_imageFile!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 48,
                                      color: Colors.black54,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'タップしてスキャン',
                                      style: TextStyle(
                                        fontSize: 16,
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
            const SizedBox(height: 12),
            _buildInsightCard(),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
            TextField(
              controller: _originalPriceController,
              decoration: const InputDecoration(
                labelText: '元の価格（値札）',
                helperText: '割引前の印刷された価格を入力',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateFinalPrice(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'セット数量',
                      hintText: '例: 3個セットの場合は3',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateFinalPrice(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('price-type-$_priceType'),
                    initialValue: _priceType,
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('通常'),
                      ),
                      DropdownMenuItem(
                        value: 'promo',
                        child: Text('特価'),
                      ),
                      DropdownMenuItem(
                        value: 'clearance',
                        child: Text('見切り'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _priceType = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: '価格タイプ'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '割引',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ToggleButtons(
                  isSelected: [
                    _selectedDiscountType == _DiscountType.none,
                    _selectedDiscountType == _DiscountType.percentage,
                    _selectedDiscountType == _DiscountType.fixedAmount,
                  ],
                  onPressed: (index) {
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
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('なし'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('% 引き'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('¥ 引き'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _discountValueController,
                  decoration: const InputDecoration(labelText: '割引額'),
                  enabled: _selectedDiscountType != _DiscountType.none,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calculateFinalPrice(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPriceSummary(),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('category-${_selectedCategory ?? 'その他'}'),
              initialValue: _selectedCategory ?? 'その他',
              items: kCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
              decoration: const InputDecoration(labelText: 'カテゴリを選択'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shopController,
                    focusNode: _shopFocusNode,
                    onChanged: (_) => _clearSelectedShopCoordinates(),
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
}
