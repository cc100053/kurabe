import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

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
      '⏱️ [Insight] Start fetching: ${stopwatch.elapsedMilliseconds}ms',
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
        '⏱️ [Insight] Location acquired: ${stopwatch.elapsedMilliseconds}ms',
      );
      _currentPosition = position;

      final result = await _supabaseService.getNearbyCheapest(
        productName: productName,
        lat: position.latitude,
        lng: position.longitude,
      );
      debugPrint(
        '⏱️ [Insight] API Response received: ${stopwatch.elapsedMilliseconds}ms',
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
                const Text(
                  'Your Record',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildYourRecordCard(userPrice),
                const SizedBox(height: 16),
                const Text(
                  'Community Insight',
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
                  'Your location locked',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              if (_currentPosition == null)
                Text(
                  'Finding nearby prices...',
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
    final relative = createdAt != null ? timeago.format(createdAt) : '';
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
              '📍 Location unavailable',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to retry with higher accuracy.',
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
              label: Text(_isLoading ? 'Retrying...' : 'Retry high accuracy'),
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
              'Checking nearby prices...',
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
        title: 'No recent community data nearby.',
        icon: Icons.info_outline,
      );
    }

    final communityPrice = (community['price'] as num?)?.toDouble();
    final communityShop = community['shop_name'] as String?;
    final communityDistance = (community['distance_meters'] as num?)
        ?.toDouble();
    final communityDate = _parseDate(community['created_at']);

    final foundCheaper =
        communityPrice != null &&
        userPrice != null &&
        communityPrice < userPrice;

    if (foundCheaper) {
      final subtitleParts = <String>[];
      final distanceText = _formatDistance(communityDistance);
      if (distanceText.isNotEmpty) subtitleParts.add(distanceText);
      final relative = communityDate != null
          ? timeago.format(communityDate)
          : null;
      if (relative != null) subtitleParts.add('Reported $relative');

      return _insightContainer(
        color: Colors.green.shade50,
        borderColor: Colors.green.shade200,
        title:
            'Found Cheaper! ${_priceFormat.format(communityPrice)}${communityShop != null ? ' at $communityShop' : ''}',
        icon: Icons.trending_down,
        subtitle: subtitleParts.isNotEmpty ? subtitleParts.join(' • ') : null,
      );
    }

    return _insightContainer(
      color: Colors.amber.shade50,
      borderColor: Colors.amber.shade200,
      title: 'You have the best price!',
      icon: Icons.emoji_events,
      subtitle: 'No lower prices found nearby.',
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
                'Unlock Nearby Prices',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sign up to see where to buy cheaper.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileTab()));
            },
            child: const Text('Link Account'),
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
}
