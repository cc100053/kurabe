import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/models/price_record_model.dart';
import '../data/repositories/price_repository.dart';
import '../domain/price/price_record_helpers.dart';
import '../main.dart';
import '../providers/subscription_provider.dart';
import '../services/location_service.dart';
import '../screens/paywall_screen.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/price_record_tile.dart';

enum _CategoryView { mine, community }

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({super.key, required this.categoryName});

  final String categoryName;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  final PriceRepository _priceRepository = PriceRepository();
  final TextEditingController _mySearchController = TextEditingController();
  final TextEditingController _communitySearchController =
      TextEditingController();
  final FocusNode _mySearchFocusNode = FocusNode();
  final FocusNode _communitySearchFocusNode = FocusNode();

  _CategoryView _selectedView = _CategoryView.mine;
  Future<List<PriceRecordModel>>? _myRecordsFuture;
  Future<List<PriceRecordModel>>? _communityFuture;
  static const int _communityRadiusMeters = 3000;
  bool _guestBlocked = false;
  String? _locationError;
  ProviderSubscription<SubscriptionState>? _subscriptionSub;
  String _mySearchQuery = '';
  String _communitySearchQuery = '';
  bool _isMySearchFocused = false;
  bool _isCommunitySearchFocused = false;

  @override
  void initState() {
    super.initState();
    _myRecordsFuture =
        _priceRepository.getMyRecordsByCategory(widget.categoryName.trim());
    _mySearchController.addListener(_onMySearchChanged);
    _communitySearchController.addListener(_onCommunitySearchChanged);
    _mySearchFocusNode.addListener(_onMySearchFocusChanged);
    _communitySearchFocusNode.addListener(_onCommunitySearchFocusChanged);
    _subscriptionSub = ref.listenManual<SubscriptionState>(
      subscriptionProvider,
      (previous, next) {
        final prevPro = previous?.isPro ?? false;
        if (prevPro != next.isPro &&
            mounted &&
            _selectedView == _CategoryView.community) {
          if (next.isPro) {
            setState(() {
              _guestBlocked = false;
              _communityFuture = _fetchCommunityRecords(forceRefresh: true);
            });
          } else {
            setState(() {
              _guestBlocked = true;
              _communityFuture = null;
            });
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _subscriptionSub?.close();
    _mySearchController.dispose();
    _communitySearchController.dispose();
    _mySearchFocusNode.dispose();
    _communitySearchFocusNode.dispose();
    super.dispose();
  }

  void _onToggle(_CategoryView view) {
    if (view == _selectedView) return;
    setState(() {
      _selectedView = view;
      _guestBlocked = false;
      _locationError = null;
    });
    if (view == _CategoryView.community) {
      final isPro = ref.read(subscriptionProvider).isPro;
      if (!isPro) {
        setState(() => _guestBlocked = true);
        return;
      }
      _communityFuture ??= _fetchCommunityRecords();
    }
  }

  void _onMySearchChanged() {
    final next = _mySearchController.text.trim();
    if (next == _mySearchQuery) return;
    if (!mounted) return;
    setState(() => _mySearchQuery = next);
  }

  void _onCommunitySearchChanged() {
    final next = _communitySearchController.text.trim();
    if (next == _communitySearchQuery) return;
    if (!mounted) return;
    setState(() => _communitySearchQuery = next);
  }

  void _onMySearchFocusChanged() {
    if (!mounted) return;
    setState(() => _isMySearchFocused = _mySearchFocusNode.hasFocus);
  }

  void _onCommunitySearchFocusChanged() {
    if (!mounted) return;
    setState(
      () => _isCommunitySearchFocused = _communitySearchFocusNode.hasFocus,
    );
  }

  Future<List<PriceRecordModel>> _fetchCommunityRecords({
    bool forceRefresh = false,
  }) async {
    final trimmed = widget.categoryName.trim();
    if (trimmed.isEmpty) return <PriceRecordModel>[];
    final isPro = ref.read(subscriptionProvider).isPro;
    if (!isPro) {
      setState(() => _guestBlocked = true);
      return <PriceRecordModel>[];
    }
    if (_priceRepository.isGuest) {
      setState(() => _guestBlocked = true);
      return <PriceRecordModel>[];
    }

    final locationResult = await LocationRepository.instance.ensurePosition(
      cacheMaxAge: const Duration(minutes: 5),
    );
    final position = locationResult.position;
    if (position == null) {
      if (!mounted) return <PriceRecordModel>[];
      setState(
        () => _locationError = LocationRepository.instance
            .messageForFailure(locationResult.failure?.reason),
      );
      return <PriceRecordModel>[];
    }

    if (!mounted) return <PriceRecordModel>[];
    setState(() => _locationError = null);
    final lat = position.latitude;
    final lng = position.longitude;
    final result = await _priceRepository.getNearbyRecordsByCategory(
      categoryTag: trimmed,
      lat: lat,
      lng: lng,
      radiusMeters: _communityRadiusMeters,
      forceRefresh: forceRefresh,
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isCommunity = _selectedView == _CategoryView.community;
    final searchController =
        isCommunity ? _communitySearchController : _mySearchController;
    final searchFocusNode =
        isCommunity ? _communitySearchFocusNode : _mySearchFocusNode;
    final isSearchFocused =
        isCommunity ? _isCommunitySearchFocused : _isMySearchFocused;
    final searchHint =
        isCommunity ? 'コミュニティを検索...' : '自分の記録を検索...';

    return Scaffold(
      backgroundColor: isCommunity
          ? const Color(0xFFF0F9F7) // Light teal tint for community
          : KurabeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: KurabeColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold),
            color: KurabeColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Segmented control
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: KurabeColors.divider,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildSegmentButton(
                    icon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                    label: '自分の記録',
                    isSelected: _selectedView == _CategoryView.mine,
                    onTap: () => _onToggle(_CategoryView.mine),
                  ),
                  const SizedBox(width: 4),
                  _buildSegmentButton(
                    icon: PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
                    label: 'コミュニティ',
                    isSelected: _selectedView == _CategoryView.community,
                    onTap: () => _onToggle(_CategoryView.community),
                  ),
                ],
              ),
            ),
          ),

          // Community info banner
          if (isCommunity)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: KurabeColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: KurabeColors.primary.withAlpha(51),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                      color: KurabeColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '近く${_communityRadiusMeters ~/ 1000}kmのコミュニティ投稿を表示',
                        style: TextStyle(
                          color: KurabeColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _buildSearchBar(
              controller: searchController,
              focusNode: searchFocusNode,
              isFocused: isSearchFocused,
              hintText: searchHint,
            ),
          ),

          const SizedBox(height: 4),

          // Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _selectedView == _CategoryView.mine
                  ? _buildMyRecords()
                  : _buildCommunityRecords(),
            ),
          ),
        ],
      ),
    );
  }

  List<PriceRecordModel> _applySearchFilter(
    List<PriceRecordModel> records,
    String query,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return records;
    final needle = trimmed.toLowerCase();
    return records
        .where(
          (record) =>
              record.productName.toLowerCase().contains(needle) ||
              (record.shopName ?? '').toLowerCase().contains(needle),
        )
        .toList();
  }

  Widget _buildSearchBar({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hintText,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: KurabeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? KurabeColors.primary : KurabeColors.border,
          width: isFocused ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? KurabeColors.primary.withAlpha(26)
                : Colors.black.withAlpha(8),
            blurRadius: isFocused ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: KurabeColors.textPrimary,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
              color:
                  isFocused ? KurabeColors.primary : KurabeColors.textTertiary,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 50,
            minHeight: 50,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                    color: KurabeColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () {
                    controller.clear();
                    focusNode.unfocus();
                  },
                )
              : null,
          hintText: hintText,
          hintStyle: TextStyle(
            color: KurabeColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          filled: false,
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? KurabeColors.primary
                    : KurabeColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? KurabeColors.textPrimary
                      : KurabeColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyRecords() {
    return FutureBuilder<List<PriceRecordModel>>(
      future: _myRecordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KurabeColors.primary,
            ),
          );
        }
        if (snapshot.hasError) {
          return _buildErrorState('${snapshot.error}');
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return _buildEmptyState(
            icon: PhosphorIcons.folder(PhosphorIconsStyle.duotone),
            message: 'このカテゴリの履歴はありません',
          );
        }
        final filteredRecords = _applySearchFilter(records, _mySearchQuery);
        if (_mySearchQuery.isNotEmpty && filteredRecords.isEmpty) {
          return _buildEmptyState(
            icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone),
            message: '検索結果が見つかりませんでした',
          );
        }
        return ListView.builder(
          key: const ValueKey('mine'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: filteredRecords.length,
          itemBuilder: (context, index) {
            return PriceRecordTile(record: filteredRecords[index]);
          },
        );
      },
    );
  }

  Widget _buildCommunityRecords() {
    _communityFuture ??= _fetchCommunityRecords();
    if (_guestBlocked) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final minHeight = (constraints.maxHeight - bottomInset)
              .clamp(0.0, double.infinity);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(32, 32, 32, bottomInset + 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: KurabeColors.primary.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.lock(PhosphorIconsStyle.duotone),
                        size: 48,
                        color: KurabeColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'コミュニティ価格はPro限定です',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: KurabeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'アップグレードして近隣の最安値を確認しましょう。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: KurabeColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _handlePaywallTap,
                      child: const Text('詳細を見るにはロック解除'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    if (_locationError != null) {
      return _buildEmptyState(
        icon: PhosphorIcons.prohibit(PhosphorIconsStyle.duotone),
        message: _locationError!,
      );
    }
    return RefreshIndicator(
      color: KurabeColors.primary,
      onRefresh: () async {
        setState(() {
          _communityFuture = _fetchCommunityRecords(forceRefresh: true);
        });
        await _communityFuture;
      },
      child: FutureBuilder<List<PriceRecordModel>>(
        future: _communityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: KurabeColors.primary,
              ),
            );
          }
          if (snapshot.hasError) {
            return _buildErrorState('${snapshot.error}');
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return _buildEmptyState(
              icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone),
              message: '近くの投稿が見つかりませんでした',
            );
          }
          final filteredRecords =
              _applySearchFilter(records, _communitySearchQuery);
          if (_communitySearchQuery.isNotEmpty && filteredRecords.isEmpty) {
            return _buildEmptyState(
              icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone),
              message: '検索結果が見つかりませんでした',
            );
          }
          final minUnitPriceByName =
              PriceRecordHelpers.minUnitPriceByName(filteredRecords);
          return ListView.builder(
            key: const ValueKey('community'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: filteredRecords.length,
            itemBuilder: (context, index) {
              final record = filteredRecords[index];
              final isCheapest =
                  PriceRecordHelpers.isCheapest(record, minUnitPriceByName);
              return PriceRecordTile(
                record: record,
                isCheapestOverride: isCheapest,
              );
            },
          );
        },
      ),
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

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: KurabeColors.textTertiary.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: KurabeColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: KurabeColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: KurabeColors.error.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.warningCircle(PhosphorIconsStyle.duotone),
                size: 48,
                color: KurabeColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'エラー: $error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: KurabeColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
