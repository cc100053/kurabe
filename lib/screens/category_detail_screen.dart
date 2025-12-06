import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../widgets/community_product_tile.dart';

enum _CategoryView { mine, community }

class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({super.key, required this.categoryName});

  final String categoryName;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  _CategoryView _selectedView = _CategoryView.mine;
  Future<List<Map<String, dynamic>>>? _myRecordsFuture;
  Future<List<Map<String, dynamic>>>? _communityFuture;
  List<Map<String, dynamic>>? _communityCache;
  DateTime? _communityCacheTime;
  static const Duration _communityCacheTtl = Duration(minutes: 10);
  bool _guestBlocked = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _myRecordsFuture =
        _supabaseService.getMyRecordsByCategory(widget.categoryName.trim());
  }

  void _onToggle(_CategoryView view) {
    if (view == _selectedView) return;
    setState(() {
      _selectedView = view;
      _guestBlocked = false;
      _locationError = null;
      if (view == _CategoryView.community) {
        _communityFuture ??= _fetchCommunityRecords();
      }
    });
  }

  Widget _buildSegment(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  bool _isCommunityCacheFresh() {
    if (_communityCache == null || _communityCacheTime == null) return false;
    return DateTime.now().difference(_communityCacheTime!) < _communityCacheTtl;
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityRecords({
    bool forceRefresh = false,
  }) async {
    final trimmed = widget.categoryName.trim();
    if (trimmed.isEmpty) return [];
    if (!forceRefresh && _isCommunityCacheFresh()) {
      return _communityCache!;
    }
    if (_supabaseService.isGuest) {
      setState(() => _guestBlocked = true);
      return [];
    }

    final cachedLatLng = LocationService.instance.getFreshLatLng(
      maxAge: const Duration(minutes: 5),
    );
    double? lat = cachedLatLng?.$1;
    double? lng = cachedLatLng?.$2;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return [];
      setState(() => _locationError = '位置情報の許可が必要です');
      return [];
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return [];
      setState(() => _locationError = '位置情報サービスをオンにしてください');
      return [];
    }

    Position? position;
    if (lat == null || lng == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }
      position ??= await Geolocator.getLastKnownPosition();
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 6),
          );
        } catch (_) {
          position = null;
        }
      }
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    }
    if (lat == null || lng == null) {
      if (!mounted) return [];
      setState(() => _locationError = '現在地を取得できませんでした');
      return [];
    }

    if (!mounted) return [];
    setState(() => _locationError = null);
    final result = await _supabaseService.getNearbyRecordsByCategory(
      categoryTag: trimmed,
      lat: lat,
      lng: lng,
      radiusMeters: 5000,
    );
    _communityCache = result;
    _communityCacheTime = DateTime.now();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isCommunity = _selectedView == _CategoryView.community;
    final bgColor = isCommunity ? Colors.blueGrey.shade50 : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      backgroundColor: bgColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: CupertinoSlidingSegmentedControl<_CategoryView>(
                groupValue: _selectedView,
                backgroundColor: Colors.transparent,
                thumbColor: Colors.white,
                padding: EdgeInsets.zero,
                children: {
                  _CategoryView.mine: _buildSegment('自分の記録', Icons.person_outline),
                  _CategoryView.community: _buildSegment('コミュニティ', Icons.public),
                },
                onValueChanged: (value) {
                  if (value != null) _onToggle(value);
                },
              ),
            ),
          ),
          if (isCommunity)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      color: Colors.blueGrey.shade700, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '近く5kmのコミュニティ投稿を表示',
                      style: TextStyle(color: Colors.blueGrey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
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

  Widget _buildMyRecords() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _myRecordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('このカテゴリの履歴はありません'));
        }
        return ListView.builder(
          key: const ValueKey('mine'),
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            return CommunityProductTile(record: records[index]);
          },
        );
      },
    );
  }

  Widget _buildCommunityRecords() {
    _communityFuture ??= _fetchCommunityRecords();
    if (_guestBlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.lock, size: 32, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'コミュニティ情報は登録ユーザーのみ利用できます',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    if (_locationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _locationError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _communityCache = null;
          _communityCacheTime = null;
          _communityFuture = _fetchCommunityRecords(forceRefresh: true);
        });
        await _communityFuture;
      },
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _communityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text('近くの投稿が見つかりませんでした'));
          }
          final minUnitPriceByName = _findMinUnitPriceByName(records);
          return ListView.builder(
            key: const ValueKey('community'),
            padding: const EdgeInsets.all(12),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final unitPrice = _computeUnitPrice(record);
              final productName =
                  (record['product_name'] as String?)?.trim().toLowerCase() ?? '';
              final minForName = minUnitPriceByName[productName];
              final isCheapest = unitPrice != null &&
                  minForName != null &&
                  (unitPrice - minForName).abs() < 1e-6;
              return CommunityProductTile(
                record: record,
                isCheapestOverride: isCheapest,
              );
            },
          );
        },
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
