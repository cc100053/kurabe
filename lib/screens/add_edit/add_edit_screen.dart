import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants/categories.dart';
import '../../constants/category_visuals.dart';
import '../../data/config/app_config.dart';
import '../../data/repositories/price_repository.dart';
import '../../domain/price/discount_type.dart';
import '../../main.dart';
import '../../providers/subscription_provider.dart';
import '../../services/google_places_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/add_edit_insight_card.dart';
import '../../widgets/price_summary_card.dart';
import '../paywall_screen.dart';
import '../smart_camera_screen.dart';
import 'add_edit_providers.dart';
import 'add_edit_state.dart';
import 'add_edit_view_model.dart';

enum _ImageAcquisitionOption { smartCamera, gallery }

class AddEditScreen extends ConsumerStatefulWidget {
  const AddEditScreen({super.key});

  @override
  ConsumerState<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends ConsumerState<AddEditScreen> {
  static const String _manualInputSentinel = '__manual_shop_input__';

  final PriceRepository _priceRepository = PriceRepository();
  late final String _placesApiKey;
  late final NumberFormat _yenNumberFormat;
  final _productController = TextEditingController();
  final _taxExcludedPriceController = TextEditingController();
  final _taxIncludedPriceController = TextEditingController();
  final _taxExcludedFocusNode = FocusNode();
  final _taxIncludedFocusNode = FocusNode();
  final _quantityController = TextEditingController();
  final _discountValueController = TextEditingController();
  final _shopController = TextEditingController();
  final _shopFocusNode = FocusNode();
  final GlobalKey _priceTypeDropdownKey = GlobalKey();

  bool _isCategorySheetOpen = false;
  bool _isSavingDialogVisible = false;
  bool _isRefreshingShops = false;
  late final ProviderSubscription<AddEditState> _stateSubscription;
  late final ProviderSubscription<bool> _savingSubscription;
  late final ProviderSubscription<AsyncValue<List<GooglePlace>>>
      _nearbyShopsSubscription;

  @override
  void initState() {
    super.initState();
    _placesApiKey = ref.read(appConfigProvider).googlePlacesApiKey ?? '';
    _yenNumberFormat = NumberFormat.decimalPattern('ja_JP');
    _taxExcludedFocusNode.addListener(_handleTaxExcludedFocusChange);
    _taxIncludedFocusNode.addListener(_handleTaxIncludedFocusChange);
    _syncControllers(ref.read(addEditViewModelProvider));

    _stateSubscription = ref.listenManual<AddEditState>(
      addEditViewModelProvider,
      (previous, next) {
        _syncControllers(next);
      },
    );

    _savingSubscription = ref.listenManual<bool>(
      addEditViewModelProvider.select((state) => state.isSaving),
      (previous, next) {
        if (next) {
          _showSavingDialog();
        } else {
          _hideSavingDialog();
        }
      },
    );

    _nearbyShopsSubscription =
        ref.listenManual<AsyncValue<List<GooglePlace>>>(
      nearbyShopsProvider(_placesApiKey),
      (previous, next) {
        next.whenData(
          (shops) => ref
              .read(addEditViewModelProvider.notifier)
              .applyNearbyShops(shops),
        );
      },
    );
  }

  @override
  void dispose() {
    _productController.dispose();
    _taxExcludedPriceController.dispose();
    _taxIncludedPriceController.dispose();
    _taxExcludedFocusNode
      ..removeListener(_handleTaxExcludedFocusChange)
      ..dispose();
    _taxIncludedFocusNode
      ..removeListener(_handleTaxIncludedFocusChange)
      ..dispose();
    _quantityController.dispose();
    _discountValueController.dispose();
    _shopController.dispose();
    _shopFocusNode.dispose();
    _stateSubscription.close();
    _savingSubscription.close();
    _nearbyShopsSubscription.close();
    super.dispose();
  }

  void _syncControllers(AddEditState state) {
    _syncController(_productController, state.productName);
    _syncPriceController(
      controller: _taxExcludedPriceController,
      focusNode: _taxExcludedFocusNode,
      rawValue: state.taxExcludedPrice,
    );
    _syncPriceController(
      controller: _taxIncludedPriceController,
      focusNode: _taxIncludedFocusNode,
      rawValue: state.taxIncludedPrice,
    );
    _syncController(_quantityController, state.quantity);
    _syncController(_discountValueController, state.discountValue);
    _syncController(_shopController, state.shopName);
  }

  void _syncPriceController({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String rawValue,
  }) {
    if (focusNode.hasFocus) return;
    final display = _formatYenDigits(rawValue);
    _syncController(controller, display);
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _handleTaxExcludedFocusChange() {
    if (_taxExcludedFocusNode.hasFocus) {
      _syncController(
        _taxExcludedPriceController,
        _stripToDigits(_taxExcludedPriceController.text),
      );
    } else {
      _syncController(
        _taxExcludedPriceController,
        _formatYenDigits(_taxExcludedPriceController.text),
      );
    }
  }

  void _handleTaxIncludedFocusChange() {
    if (_taxIncludedFocusNode.hasFocus) {
      _syncController(
        _taxIncludedPriceController,
        _stripToDigits(_taxIncludedPriceController.text),
      );
    } else {
      _syncController(
        _taxIncludedPriceController,
        _formatYenDigits(_taxIncludedPriceController.text),
      );
    }
  }

  String _stripToDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits;
  }

  String _formatYenDigits(String input) {
    final digits = _stripToDigits(input);
    if (digits.isEmpty) return '';
    final value = int.tryParse(digits);
    if (value == null) return digits;
    return _yenNumberFormat.format(value);
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
    await _analyzeImageFile(File(path));
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
      await _analyzeImageFile(savedFile);
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

  Future<void> _analyzeImageFile(File file) async {
    final viewModel = ref.read(addEditViewModelProvider.notifier);
    try {
      await viewModel.analyzeImage(file);
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyGeminiError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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

  Future<void> _showShopSelectionSheet(
    AddEditState state,
    AddEditViewModel viewModel,
  ) async {
    if (state.nearbyShops.isEmpty) {
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
                  ...state.nearbyShops.map(
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
      viewModel.setShopName(state.shopName);
      _shopFocusNode.requestFocus();
      return;
    }
    final chosenPlace = state.nearbyShops.firstWhere(
      (place) => place.name == selected,
      orElse: () => state.nearbyShops.first,
    );
    viewModel.selectNearbyShop(chosenPlace);
  }

  Widget? _buildShopSubtitle(GooglePlace place) {
    final parts = <String>[];
    if (place.distanceMeters != null) {
      parts.add('${place.distanceMeters!.toStringAsFixed(0)} m');
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' • '));
  }

  Future<void> _refreshNearbyShops() async {
    if (_placesApiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Places APIキーがありません。.envにGOOGLE_PLACES_API_KEYを設定してください。',
          ),
        ),
      );
      return;
    }
    setState(() => _isRefreshingShops = true);
    final shops = await LocationRepository.instance.fetchNearbyShops(
      apiKey: _placesApiKey,
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() => _isRefreshingShops = false);
    if (shops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('近くに店舗が見つかりませんでした。')),
      );
      return;
    }
    final sorted = _prioritizeShops(shops);
    final viewModel = ref.read(addEditViewModelProvider.notifier);
    viewModel.applyNearbyShops(sorted);
    viewModel.selectNearbyShop(sorted.first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('最寄りの店舗を選択しました: ${sorted.first.name}'),
      ),
    );
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

  void _showSavingDialog() {
    if (_isSavingDialogVisible) return;
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

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km 先';
    }
    return '${meters.toStringAsFixed(0)} m 先';
  }

  int _parseQuantity(String input) {
    final parsed = int.tryParse(input.trim());
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addEditViewModelProvider);
    final viewModel = ref.read(addEditViewModelProvider.notifier);
    final isPro = ref.watch(subscriptionProvider).isPro;
    final nearbyShopsAsync = ref.watch(nearbyShopsProvider(_placesApiKey));

    final insightRequest = InsightRequest(
      productName: state.productName,
      finalTaxedTotal: state.finalTaxedTotal,
      quantity: _parseQuantity(state.quantity),
      apiKey: _placesApiKey,
      isPro: isPro,
    );
    final insightAsync = ref.watch(communityInsightProvider(insightRequest));
    final isInsightLoading = insightAsync.isLoading &&
        state.productName.trim().isNotEmpty &&
        state.finalTaxedTotal != null;

    final isFetchingShops =
        nearbyShopsAsync.isLoading || _isRefreshingShops;

    return Scaffold(
      appBar: AppBar(title: const Text('記録を追加')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _AddEditImageCard(
                imageFile: state.imageFile,
                isAnalyzing: state.isAnalyzing,
                onTap: _handleImageTap,
              ),
            ),
            const SizedBox(height: 8),
            AddEditInsightCard(
              insight: insightAsync.value ?? AddEditInsight.idle,
              isLoading: isInsightLoading,
              isPro: isPro,
              onUpgradeTap: _handlePaywallTap,
              formatDistance: _formatDistance,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _productController,
              decoration: const InputDecoration(labelText: '商品名'),
              onChanged: viewModel.updateProductName,
            ),
            if (state.suggestionChips.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AddEditSuggestionChips(
                suggestions: state.suggestionChips,
                onSelected: (value) {
                  viewModel.updateProductName(value);
                  viewModel.clearSuggestions();
                },
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taxExcludedPriceController,
                    focusNode: _taxExcludedFocusNode,
                    decoration: const InputDecoration(
                      labelText: '税抜価格',
                      prefixText: '¥',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: viewModel.updateTaxExcludedPrice,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _taxIncludedPriceController,
                    focusNode: _taxIncludedFocusNode,
                    decoration: const InputDecoration(
                      labelText: '税込価格',
                      prefixText: '¥',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: viewModel.updateTaxIncludedPrice,
                  ),
                ),
              ],
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
                    onChanged: viewModel.updateQuantity,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AddEditPriceTypeDropdown(
                    dropdownKey: _priceTypeDropdownKey,
                    priceType: state.priceType,
                    onSelected: viewModel.setPriceType,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AddEditTaxControls(
              taxRate: state.taxRate,
              onToggleRate: () {
                final is8Percent = state.taxRate == 0.08;
                viewModel.setTaxRate(is8Percent ? 0.10 : 0.08);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '割引:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                _AddEditDiscountToggle(
                  discountType: state.discountType,
                  onSelected: viewModel.setDiscountType,
                ),
                if (state.discountType != DiscountType.none) ...[
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
                      onChanged: viewModel.updateDiscountValue,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            PriceSummaryCard(
              finalTaxedTotal: state.finalTaxedTotal,
              unitPrice: state.unitPrice,
              quantity: _parseQuantity(state.quantity),
            ),
            const SizedBox(height: 8),
            _AddEditCategoryPicker(
              selectedCategory: state.category,
              isSheetOpen: _isCategorySheetOpen,
              onTap: () => _showCategorySheet(viewModel),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shopController,
                    focusNode: _shopFocusNode,
                    onChanged: viewModel.setShopName,
                    decoration: InputDecoration(
                      labelText: '店舗名',
                      suffixIcon: isFetchingShops
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
                              onPressed: () =>
                                  _showShopSelectionSheet(state, viewModel),
                            ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isFetchingShops ? null : _refreshNearbyShops,
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Google Placesから自動入力',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
                child: ElevatedButton(
                onPressed: state.isSaving
                    ? null
                    : () async {
                        try {
                          await viewModel.save();
                          if (!mounted) return;
                          _hideSavingDialog();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('記録を保存しました。')),
                          );
                          Navigator.pop(context, '記録を保存しました。');
                        } on StateError catch (e) {
                          if (!mounted) return;
                          _hideSavingDialog();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          _hideSavingDialog();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('記録の保存に失敗しました: $e'),
                            ),
                          );
                        }
                      },
                child: state.isSaving
                    ? const CircularProgressIndicator()
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategorySheet(AddEditViewModel viewModel) async {
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
                          selectedCategory:
                              ref.read(addEditViewModelProvider).category,
                          onSelect: (name) {
                            viewModel.setCategory(name);
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

  Widget _buildCategoryGridBody({
    required String selectedCategory,
    required void Function(String) onSelect,
  }) {
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
        final isSelected = selectedCategory == name;

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

  void _handlePaywallTap() {
    if (_priceRepository.isGuest) {
      AppSnackbar.show(
        context,
        'ゲストは購入できません。先にログインしてください。',
        isError: true,
      );
      mainScaffoldKey.currentState?.switchToProfileTab();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
  }
}

class _AddEditImageCard extends StatelessWidget {
  const _AddEditImageCard({
    required this.imageFile,
    required this.isAnalyzing,
    required this.onTap,
  });

  final File? imageFile;
  final bool isAnalyzing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 160,
              height: 180,
              child: imageFile != null
                  ? Image.file(imageFile!, fit: BoxFit.cover)
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
          if (isAnalyzing)
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
    );
  }
}

class _AddEditSuggestionChips extends StatelessWidget {
  const _AddEditSuggestionChips({
    required this.suggestions,
    required this.onSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions
          .map(
            (s) => ActionChip(
              label: Text('✨ $s'),
              backgroundColor: Colors.green.shade100,
              onPressed: () => onSelected(s),
            ),
          )
          .toList(),
    );
  }
}

class _AddEditTaxControls extends StatelessWidget {
  const _AddEditTaxControls({
    required this.taxRate,
    required this.onToggleRate,
  });

  final double taxRate;
  final VoidCallback onToggleRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '税:',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AddEditTaxRateToggle(
            taxRate: taxRate,
            onTap: onToggleRate,
          ),
        ),
      ],
    );
  }
}

class _AddEditTaxRateToggle extends StatelessWidget {
  const _AddEditTaxRateToggle({
    required this.taxRate,
    required this.onTap,
  });

  final double taxRate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final is8Percent = taxRate == 0.08;
    return GestureDetector(
      onTap: onTap,
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
}

class _AddEditDiscountToggle extends StatelessWidget {
  const _AddEditDiscountToggle({
    required this.discountType,
    required this.onSelected,
  });

  final DiscountType discountType;
  final ValueChanged<DiscountType> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = switch (discountType) {
      DiscountType.none => 0,
      DiscountType.percentage => 1,
      DiscountType.fixedAmount => 2,
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
              Row(
                children: [
                  _buildDiscountOption(
                    label: 'なし',
                    index: 0,
                    selectedIndex: selectedIndex,
                  ),
                  _buildDiscountOption(
                    label: '%',
                    index: 1,
                    selectedIndex: selectedIndex,
                  ),
                  _buildDiscountOption(
                    label: '¥',
                    index: 2,
                    selectedIndex: selectedIndex,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiscountOption({
    required String label,
    required int index,
    required int selectedIndex,
  }) {
    final isSelected = index == selectedIndex;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onSelected(
            switch (index) {
              1 => DiscountType.percentage,
              2 => DiscountType.fixedAmount,
              _ => DiscountType.none,
            },
          );
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
}

class _AddEditPriceTypeDropdown extends StatelessWidget {
  const _AddEditPriceTypeDropdown({
    required this.dropdownKey,
    required this.priceType,
    required this.onSelected,
  });

  final GlobalKey dropdownKey;
  final String priceType;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
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
      (o) => o.value == priceType,
      orElse: () => priceTypeOptions.first,
    );

    return GestureDetector(
      key: dropdownKey,
      onTap: () => _showPriceTypePopup(context, priceTypeOptions),
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
    BuildContext context,
    List<
            ({
              String value,
              String label,
              String subtitle,
              IconData icon,
              Color iconColor
            })>
        options,
  ) async {
    final RenderBox renderBox =
        dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final screenWidth = MediaQuery.of(context).size.width;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        screenWidth - 200,
        offset.dy + size.height + 4,
        16,
        0,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: KurabeColors.surfaceElevated,
      items: options.map((option) {
        final isSelected = option.value == priceType;
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

    if (result != null && result != priceType) {
      onSelected(result);
    }
  }
}

class _AddEditCategoryPicker extends StatelessWidget {
  const _AddEditCategoryPicker({
    required this.selectedCategory,
    required this.isSheetOpen,
    required this.onTap,
  });

  final String selectedCategory;
  final bool isSheetOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = kCategoryVisuals[selectedCategory];
    final icon =
        visual?.icon ?? PhosphorIcons.tagSimple(PhosphorIconsStyle.bold);

    return GestureDetector(
      onTap: onTap,
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
                selectedCategory,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              isSheetOpen
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
}
