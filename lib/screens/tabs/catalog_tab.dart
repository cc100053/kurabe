import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../main.dart';
import '../../screens/tabs/profile_tab.dart';
import '../../constants/categories.dart';
import '../../constants/category_visuals.dart';
import '../../screens/category_detail_screen.dart';
import '../../services/supabase_service.dart';
import '../../widgets/community_product_tile.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSearchFocused = false;
  List<Map<String, dynamic>> _searchResults = [];
  Position? _currentPosition;
  Timer? _debounce;
  bool _guestBlockedSearch = false;

  static final Map<String, CategoryVisual> _categoryVisuals = kCategoryVisuals;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      _guestBlockedSearch = false;
    });
    _ensureLocation();
    _debounce?.cancel();
    if (next.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(next);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    if (_supabaseService.isGuest) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _guestBlockedSearch = true;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _supabaseService.searchCommunityPrices(
        query.trim(),
        _currentPosition?.latitude,
        _currentPosition?.longitude,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  Future<Position?> _ensureLocation() async {
    if (_currentPosition != null) return _currentPosition;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    _currentPosition = position;
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
    if (_guestBlockedSearch) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: KurabeColors.warning.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIcons.lock(PhosphorIconsStyle.duotone),
                    size: 48,
                    color: KurabeColors.warning,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'コミュニティ検索は\n登録ユーザーのみ利用できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: KurabeColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileTab()),
                    );
                  },
                  child: const Text('新規登録'),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
    if (_searchResults.isEmpty) {
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
    final minUnitPriceByName = _findMinUnitPriceByName(_searchResults);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final record = _searchResults[index];
            final unitPrice = _computeUnitPrice(record);
            final name = (record['product_name'] as String?)
                    ?.trim()
                    .toLowerCase() ??
                '';
            final minForName = minUnitPriceByName[name];
            final isCheapest = unitPrice != null &&
                minForName != null &&
                (unitPrice - minForName).abs() < 1e-6;
            return CommunityProductTile(
              record: record,
              isCheapestOverride: isCheapest,
            );
          },
          childCount: _searchResults.length,
        ),
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

            return _buildCategoryCard(context, name, visual);
          },
          childCount: kCategories.length,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String name,
    CategoryVisual visual,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(categoryName: name),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [visual.color, visual.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: visual.gradientEnd.withAlpha(77),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withAlpha(102),
                    Colors.white.withAlpha(26),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container with glass effect
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(179),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconTheme(
                      data: IconTheme.of(context).copyWith(
                        weight: visual.weight ?? 400,
                      ),
                      child: Icon(
                        visual.icon,
                        size: 26,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Label
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF374151),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double? _computeUnitPrice(Map<String, dynamic> record) {
    final explicit = (record['unit_price'] as num?)?.toDouble();
    if (explicit != null) return explicit;
    final price = (record['price'] as num?)?.toDouble();
    final quantity = (record['quantity'] as num?)?.toDouble() ?? 1;
    if (price == null) return null;
    return price / (quantity <= 0 ? 1 : quantity);
  }

  Map<String, double> _findMinUnitPriceByName(
    List<Map<String, dynamic>> records,
  ) {
    final map = <String, double>{};
    for (final record in records) {
      final unitPrice = _computeUnitPrice(record);
      if (unitPrice == null) continue;
      final name =
          (record['product_name'] as String?)?.trim().toLowerCase() ?? '';
      if (name.isEmpty) continue;
      final current = map[name];
      if (current == null || unitPrice < current) {
        map[name] = unitPrice;
      }
    }
    return map;
  }
}
