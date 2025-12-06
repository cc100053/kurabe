import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';


import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../screens/tabs/profile_tab.dart';

class ProductDetailSheet extends StatefulWidget {
  const ProductDetailSheet({super.key, required this.record});

  final Map<String, dynamic> record;

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  final SupabaseService _supabaseService = SupabaseService();
  final NumberFormat _priceFormat = NumberFormat.currency(
    symbol: '¥',
    decimalDigits: 0,
  );

  Map<String, dynamic>? _communityBestPrice;
  bool _isLoading = false;
  bool _locationUnavailable = false;
  late final bool _isGuest;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _isGuest = _supabaseService.isGuest;
    if (_isGuest) return;
    _fetchInsight();
  }

  Future<void> _fetchInsight({bool highAccuracy = false}) async {
    final productName = (widget.record['product_name'] as String?)?.trim();
    if (productName == null || productName.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    debugPrint(
      '⏱️ [インサイト] 取得開始: ${stopwatch.elapsedMilliseconds}ms',
    );

    setState(() {
      _isLoading = true;
      _locationUnavailable = false;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _communityBestPrice = null;
          _isLoading = false;
          _locationUnavailable = true;
        });
        return;
      }

      Position? position = LocationService.instance.cachedPosition;
      if (position == null) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: highAccuracy
                ? LocationAccuracy.high
                : LocationAccuracy.low,
            timeLimit: highAccuracy
                ? const Duration(seconds: 8)
                : const Duration(seconds: 4),
          );
        } on TimeoutException {
          position = null;
        }
      }
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _locationUnavailable = true;
        });
        return;
      }
      debugPrint(
        '⏱️ [インサイト] 位置取得: ${stopwatch.elapsedMilliseconds}ms',
      );
      _currentPosition = position;

      final result = await _supabaseService.getNearbyCheapest(
        productName: productName,
        lat: position.latitude,
        lng: position.longitude,
        radiusMeters: 5000, // Match list view radius
        recentDays: 7, // Cover "5 days ago" items safely
      );
      debugPrint(
        '⏱️ [インサイト] APIレスポンス受信: ${stopwatch.elapsedMilliseconds}ms',
      );
      if (!mounted) return;
      setState(() {
        _communityBestPrice = result;
        _isLoading = false;
        _locationUnavailable = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _communityBestPrice = null;
        _isLoading = false;
        _locationUnavailable = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.record['product_name'] as String? ?? '商品';
    final imageUrl = widget.record['image_url'] as String?;
    final userPrice = (widget.record['price'] as num?)?.toDouble();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(productName, imageUrl),
                const SizedBox(height: 16),

                _buildYourRecordCard(userPrice),
                const SizedBox(height: 16),
                const Text(
                  'コミュニティ情報',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildCommunityInsight(userPrice),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String productName, String? imageUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 70,
            height: 70,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: Colors.grey.shade200),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 32),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, size: 32),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              if (_currentPosition != null)
                Text(
                  '現在地を取得しました',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              if (_currentPosition == null)
                Text(
                  '近くの価格を検索中...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYourRecordCard(double? userPrice) {
    final shopName = widget.record['shop_name'] as String? ?? '店舗不明';
    final createdAt = _parseDate(widget.record['created_at']);
    final relative = createdAt != null ? _formatTimeAgo(createdAt) : '';
    final priceText = userPrice != null ? _priceFormat.format(userPrice) : '--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                priceText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              if (relative.isNotEmpty)
                Text(relative, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.store, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(shopName, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityInsight(double? userPrice) {
    if (_isGuest) {
      return _buildLockedInsightCard(context);
    }
    if (_locationUnavailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 位置情報が取得できません',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'タップして高精度で再試行します。',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _fetchInsight(highAccuracy: true),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_isLoading ? '再試行中...' : '高精度で再試行'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Expanded(child: LinearProgressIndicator(minHeight: 6)),
            const SizedBox(width: 12),
            Text(
              '近くの価格を確認中...',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    final community = _communityBestPrice;
    if (community == null) {
      return _insightContainer(
        color: Colors.grey.shade200,
        borderColor: Colors.grey.shade300,
        title: '近くに最近のデータがありません。',
        icon: Icons.info_outline,
      );
    }

    final communityPrice = (community['price'] as num?)?.toDouble();
    final communityQuantity =
        (community['quantity'] as num?)?.toDouble() ?? 1;
    final communityUnitPrice =
        (community['unit_price'] as num?)?.toDouble() ??
        _computeUnitPrice(communityPrice, communityQuantity);

    final userQuantity = (widget.record['quantity'] as num?)?.toDouble() ?? 1;
    final userUnitPrice = _computeUnitPrice(userPrice, userQuantity);
    final communityId = community['id'];
    final userId = widget.record['id'];

    final communityShop = community['shop_name'] as String?;
    final communityDistance = (community['distance_meters'] as num?)
        ?.toDouble();
    final communityDate = _parseDate(community['created_at']);

    // Compare Unit Prices for accurate "Best Price" logic
    final sameRecord = communityId != null &&
        userId != null &&
        communityId.toString() == userId.toString();
    final foundCheaper =
        communityUnitPrice != null &&
        userUnitPrice != null &&
        !sameRecord &&
        communityUnitPrice + 1e-6 < userUnitPrice;

    if (foundCheaper) {
      final subtitleParts = <String>[];
      final distanceText = _formatDistance(communityDistance);
      if (distanceText.isNotEmpty) subtitleParts.add(distanceText);
      final relative = communityDate != null
          ? _formatTimeAgo(communityDate)
          : null;
      if (relative != null) subtitleParts.add('$relativeに報告');

      final unit = community['unit'] as String? ?? '';
      final unitLabel = unit.isNotEmpty ? '/$unit' : '';

      return _insightContainer(
        color: Colors.green.shade50,
        borderColor: Colors.green.shade200,
        title:
            'より安い価格を発見！ ${_priceFormat.format(communityPrice)}${unitLabel.isNotEmpty ? unitLabel : ""}（$communityShop）',
        icon: Icons.trending_down,
        subtitle: subtitleParts.isNotEmpty ? subtitleParts.join(' • ') : null,
      );
    }

    return _insightContainer(
      color: Colors.amber.shade50,
      borderColor: Colors.amber.shade200,
      title: 'あなたが最安値です！',
      icon: Icons.emoji_events,
      subtitle: '近くにより安い価格は見つかりませんでした。',
    );
  }

  Widget _buildLockedInsightCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lock_outline),
              SizedBox(width: 8),
              Text(
                '近くの価格を解除',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'サインアップしてどこでもっと安く購入できるか確認。',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileTab()));
            },
            child: const Text('アカウントを連携'),
          ),
        ],
      ),
    );
  }

  Widget _insightContainer({
    required Color color,
    required Color borderColor,
    required String title,
    IconData? icon,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return DateFormat('MM/dd').format(date);
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is DateTime) return raw.toLocal();
    if (raw is String) return DateTime.tryParse(raw)?.toLocal();
    return null;
  }

  double? _computeUnitPrice(double? price, double quantity) {
    if (price == null) return null;
    final safeQty = quantity <= 0 ? 1 : quantity;
    return price / safeQty;
  }
}
