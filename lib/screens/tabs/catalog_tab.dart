import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../screens/tabs/profile_tab.dart';
import '../../constants/categories.dart';
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

  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Position? _currentPosition;
  Timer? _debounce;
  bool _guestBlockedSearch = false;
  static final Map<String, CategoryVisual> _categoryVisuals = {
    // Fresh / Perishables
    '野菜': CategoryVisual(color: Color(0xFFE8F5E9), icon: PhosphorIcons.carrot(PhosphorIconsStyle.bold)),
    '果物': CategoryVisual(color: Color(0xFFFFEBEE), icon: PhosphorIcons.appleLogo(PhosphorIconsStyle.bold)),
    '精肉': CategoryVisual(color: Color(0xFFFFE5E0), icon: LucideIcons.beef),
    '鮮魚': CategoryVisual(color: Color(0xFFE3F2FD), icon: PhosphorIcons.fishSimple(PhosphorIconsStyle.bold)),
    '惣菜': CategoryVisual(color: Color(0xFFFFF3E0), icon: Symbols.bento, weight: 700),
    '卵': CategoryVisual(color: Color(0xFFFFF8E1), icon: PhosphorIcons.egg(PhosphorIconsStyle.bold)),
    '乳製品': CategoryVisual(color: Color(0xFFE8F0FE), icon: PhosphorIcons.cheese(PhosphorIconsStyle.bold)),
    '豆腐・納豆・麺': CategoryVisual(color: Color(0xFFE0F2F1), icon: LucideIcons.soup),
    // Staples & Pantry
    'パン': CategoryVisual(color: Color(0xFFFFF0D5), icon: PhosphorIcons.bread(PhosphorIconsStyle.bold)),
    '米・穀物': CategoryVisual(color: Color(0xFFF7E9D7), icon: PhosphorIcons.grains(PhosphorIconsStyle.bold)),
    '調味料': CategoryVisual(color: Color(0xFFFFF3E0), icon: PhosphorIcons.drop(PhosphorIconsStyle.bold)),
    'インスタント': CategoryVisual(color: Color(0xFFFCE4EC), icon: PhosphorIcons.timer(PhosphorIconsStyle.bold)),
    // Drinks & Snacks
    '飲料': CategoryVisual(color: Color(0xFFE0F7FA), icon: PhosphorIcons.coffee(PhosphorIconsStyle.bold)),
    'お酒': CategoryVisual(color: Color(0xFFF3E5F5), icon: PhosphorIcons.beerStein(PhosphorIconsStyle.bold)),
    'お菓子': CategoryVisual(color: Color(0xFFFFF0F5), icon: PhosphorIcons.cookie(PhosphorIconsStyle.bold)),
    // Others
    '冷凍食品': CategoryVisual(color: Color(0xFFE0F2FF), icon: PhosphorIcons.snowflake(PhosphorIconsStyle.bold)),
    '日用品': CategoryVisual(color: Color(0xFFF5F5F5), icon: PhosphorIcons.sprayBottle(PhosphorIconsStyle.bold)),
    'その他': CategoryVisual(color: Color(0xFFECEFF1), icon: PhosphorIcons.dotsThree(PhosphorIconsStyle.bold)),
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() {
      _searchQuery = next;
      _guestBlockedSearch = false;
    });
    _ensureLocation(); // fire and forget to warm location cache
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('カタログ'),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.03 * 255).round()),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  hintText: '商品を検索...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: false,
                ),
              ),
            ),
          ),
          Expanded(
            child: isSearching ? _buildSearchResults() : _buildCategoryGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_guestBlockedSearch) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'コミュニティ検索は登録ユーザーのみ利用できます。',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ProfileTab()));
                },
                child: const Text('新規登録'),
              ),
            ],
          ),
        ),
      );
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text('結果が見つかりませんでした'));
    }
    final minUnitPriceByName = _findMinUnitPriceByName(_searchResults);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final record = _searchResults[index];
        final unitPrice = _computeUnitPrice(record);
        final name =
            (record['product_name'] as String?)?.trim().toLowerCase() ?? '';
        final minForName = minUnitPriceByName[name];
        final isCheapest = unitPrice != null &&
            minForName != null &&
            (unitPrice - minForName).abs() < 1e-6;
        return CommunityProductTile(
          record: record,
          isCheapestOverride: isCheapest,
        );
      },
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Increased padding
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85, // Taller cards
      children: kCategories.asMap().entries.map((entry) {
        final name = entry.value;
        final visual = _categoryVisuals[name] ?? CategoryVisual(color: Colors.white, icon: Icons.grid_view);
        
        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(categoryName: name),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: visual.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.6 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: IconTheme(
                    data: IconTheme.of(context).copyWith(weight: visual.weight),
                    child: Icon(visual.icon, size: 28, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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

class CategoryVisual {
  CategoryVisual({required this.color, required this.icon, this.weight});
  final Color color;
  final IconData icon;
  final double? weight;
}
