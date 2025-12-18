import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../main.dart';
import '../providers/subscription_provider.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../screens/paywall_screen.dart';
import '../widgets/community_product_tile.dart';

enum _CategoryView { mine, community }

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({super.key, required this.categoryName});

  final String categoryName;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  _CategoryView _selectedView = _CategoryView.mine;
  Future<List<Map<String, dynamic>>>? _myRecordsFuture;
  Future<List<Map<String, dynamic>>>? _communityFuture;
  List<Map<String, dynamic>>? _communityCache;
  DateTime? _communityCacheTime;
  static const Duration _communityCacheTtl = Duration(minutes: 10);
  static const int _communityRadiusMeters = 3000;
  bool _guestBlocked = false;
  String? _locationError;
  ProviderSubscription<SubscriptionState>? _subscriptionSub;

  @override
  void initState() {
    super.initState();
    _myRecordsFuture =
        _supabaseService.getMyRecordsByCategory(widget.categoryName.trim());
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
              _communityCache = null;
              _communityCacheTime = null;
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

  bool _isCommunityCacheFresh() {
    if (_communityCache == null || _communityCacheTime == null) return false;
    return DateTime.now().difference(_communityCacheTime!) < _communityCacheTtl;
  }

  Future<List<Map<String, dynamic>>> _fetchCommunityRecords({
    bool forceRefresh = false,
  }) async {
    final trimmed = widget.categoryName.trim();
    if (trimmed.isEmpty) return [];
    final isPro = ref.read(subscriptionProvider).isPro;
    if (!isPro) {
      setState(() => _guestBlocked = true);
      return [];
    }
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
      radiusMeters: _communityRadiusMeters,
    );
    _communityCache = result;
    _communityCacheTime = DateTime.now();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isCommunity = _selectedView == _CategoryView.community;

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

          const SizedBox(height: 8),

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
    return FutureBuilder<List<Map<String, dynamic>>>(
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
        return ListView.builder(
          key: const ValueKey('mine'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
          padding: const EdgeInsets.all(32),
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
          final minUnitPriceByName = _findMinUnitPriceByName(records);
          return ListView.builder(
            key: const ValueKey('community'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final unitPrice = _computeUnitPrice(record);
              final productName =
                  (record['product_name'] as String?)?.trim().toLowerCase() ??
                      '';
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
