import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../screens/tabs/profile_tab.dart';
import '../../constants/categories.dart';
import '../../screens/category_detail_screen.dart';
import '../../services/supabase_service.dart';
import '../../widgets/shopping_card.dart';

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
      appBar: AppBar(title: const Text('商品')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search for products...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
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
                'Community Search is for registered users only.',
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
                child: const Text('Sign Up'),
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
      return const Center(child: Text('No results'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return ShoppingCard(record: _searchResults[index]);
      },
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(12),
      childAspectRatio: 1.1,
      children: kCategories.map((name) {
        final icon = _iconForCategory(name);
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(categoryName: name),
                ),
              );
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case '野菜':
        return Icons.eco;
      case '果物':
        return Icons.local_florist;
      case '精肉':
        return Icons.set_meal;
      case '鮮魚':
        return Icons.water;
      case '惣菜':
        return Icons.restaurant;
      case '乳製品':
        return Icons.icecream;
      case '卵':
        return Icons.breakfast_dining;
      case '調味料':
        return Icons.ramen_dining;
      case '飲料':
        return Icons.local_drink;
      case 'お菓子':
        return Icons.cake;
      case 'インスタント':
        return Icons.rice_bowl;
      case '冷凍食品':
        return Icons.ac_unit;
      case '米/パン':
        return Icons.bakery_dining;
      case '日用品':
        return Icons.inventory_2;
      case 'その他':
      default:
        return Icons.category;
    }
  }
}
