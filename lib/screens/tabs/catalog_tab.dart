import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/price_record_model.dart';
import '../../data/repositories/price_repository.dart';
import '../../domain/price/price_record_helpers.dart';
import '../../main.dart';
import '../../constants/categories.dart';
import '../../constants/category_visuals.dart';
import '../../providers/subscription_provider.dart';
import '../../screens/paywall_screen.dart';
import '../../screens/category_detail_screen.dart';
import '../../widgets/price_record_tile.dart';
import '../../widgets/category_card.dart';
import '../../services/location_service.dart';

class CatalogTab extends ConsumerStatefulWidget {
  const CatalogTab({super.key});

  @override
  ConsumerState<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<CatalogTab> {
  final PriceRepository _priceRepository = PriceRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSearchFocused = false;
  List<PriceRecordModel> _searchResults = [];
  List<PriceRecordModel> _mySearchResults = [];
  int _communityResultCount = 0;
  Position? _currentPosition;
  Timer? _debounce;
  ProviderSubscription<SubscriptionState>? _subscriptionSub;

  static final Map<String, CategoryVisual> _categoryVisuals = kCategoryVisuals;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    _subscriptionSub = ref.listenManual<SubscriptionState>(
      subscriptionProvider,
      (previous, next) {
        final prevPro = previous?.isPro ?? false;
        if (prevPro != next.isPro && _searchQuery.isNotEmpty) {
          _performSearch(_searchQuery);
        }
        if (!next.isPro && mounted) {
          setState(() {
            _searchResults = [];
            _communityResultCount = 0;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _subscriptionSub?.close();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() {
      _searchQuery = next;
    });
    _ensureLocation();
    _debounce?.cancel();
    if (next.isEmpty) {
      setState(() {
        _searchResults = [];
        _mySearchResults = [];
        _communityResultCount = 0;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(next);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _isSearching = true;
      _communityResultCount = 0;
    });
    try {
      final myResults = await _priceRepository.searchMyPrices(trimmed);
      final subState = ref.read(subscriptionProvider);
      final isPro = subState.isPro;
      List<PriceRecordModel> communityResults = [];
      int communityCount = 0;
      if (isPro) {
        communityResults = await _priceRepository.searchCommunityPrices(
          trimmed,
          _currentPosition?.latitude,
          _currentPosition?.longitude,
        );
        communityCount = communityResults.length;
      } else {
        communityCount = await _priceRepository.countCommunityPrices(
          trimmed,
          _currentPosition?.latitude,
          _currentPosition?.longitude,
          limit: 30,
        );
      }
      if (!mounted) return;
      setState(() {
        _mySearchResults = myResults;
        _searchResults = communityResults;
        _communityResultCount = communityCount;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _mySearchResults = [];
        _communityResultCount = 0;
      });
    }
  }

  Future<Position?> _ensureLocation() async {
    if (_currentPosition != null) return _currentPosition;
    final result = await LocationRepository.instance.ensurePosition(
      cacheMaxAge: const Duration(minutes: 5),
    );
    final position = result.position;
    if (position != null) {
      _currentPosition = position;
    }
    return position;
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: KurabeColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: KurabeColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 70,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Text(
                        'カタログ',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: KurabeColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: KurabeColors.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${kCategories.length}カテゴリ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: KurabeColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: KurabeColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isSearchFocused
                        ? KurabeColors.primary
                        : KurabeColors.border,
                    width: _isSearchFocused ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isSearchFocused
                          ? KurabeColors.primary.withAlpha(26)
                          : Colors.black.withAlpha(8),
                      blurRadius: _isSearchFocused ? 16 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
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
                        color: _isSearchFocused
                            ? KurabeColors.primary
                            : KurabeColors.textTertiary,
                        size: 22,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 50,
                      minHeight: 50,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                              color: KurabeColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                            },
                          )
                        : null,
                    hintText: '商品を検索...',
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
              ),
            ),
          ),

          // Content
          if (isSearching)
            _buildSearchResultsSliver()
          else
            _buildCategoryGridSliver(),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildSearchResultsSliver() {
    final subState = ref.watch(subscriptionProvider);
    final isPro = subState.isPro;
    if (_isSearching) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: KurabeColors.primary,
          ),
        ),
      );
    }
    final hasResults =
        _mySearchResults.isNotEmpty || (isPro && _searchResults.isNotEmpty);
    if (!hasResults && _communityResultCount == 0) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.duotone),
                size: 56,
                color: KurabeColors.textTertiary,
              ),
              const SizedBox(height: 16),
              const Text(
                '結果が見つかりませんでした',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: KurabeColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final children = <Widget>[];
    if (_mySearchResults.isNotEmpty) {
      children.addAll([
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            '自分の記録',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: KurabeColors.textPrimary,
            ),
          ),
        ),
        ..._mySearchResults.map(
          (record) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PriceRecordTile(record: record),
          ),
        ),
        const SizedBox(height: 8),
      ]);
    }
    if (isPro && _searchResults.isNotEmpty) {
      final minUnitPriceByName =
          PriceRecordHelpers.minUnitPriceByName(_searchResults);
      children.addAll([
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            'コミュニティ価格',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: KurabeColors.textPrimary,
            ),
          ),
        ),
        ..._searchResults.map((record) {
          final isCheapest =
              PriceRecordHelpers.isCheapest(record, minUnitPriceByName);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PriceRecordTile(
              record: record,
              isCheapestOverride: isCheapest,
            ),
          );
        }),
      ]);
    }
    if (!isPro && _communityResultCount > 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KurabeColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KurabeColors.primary.withAlpha(51)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        PhosphorIcons.lock(PhosphorIconsStyle.fill),
                        color: KurabeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'コミュニティで$_communityResultCount件のより安い価格を発見！',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: KurabeColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Proで全ての店舗と価格を解放。',
                  style: TextStyle(
                    color: KurabeColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  },
                  child: const Text('詳細を見るにはロック解除'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(children),
      ),
    );
  }

  Widget _buildCategoryGridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final name = kCategories[index];
            final visual = _categoryVisuals[name] ??
                CategoryVisual(
                  color: Colors.grey.shade100,
                  gradientEnd: Colors.grey.shade200,
                  icon: PhosphorIcons.gridFour(PhosphorIconsStyle.fill),
                );

            return CategoryCard(
              name: name,
              visual: visual,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CategoryDetailScreen(categoryName: name),
                  ),
                );
              },
            );
          },
          childCount: kCategories.length,
        ),
      ),
    );
  }
}
