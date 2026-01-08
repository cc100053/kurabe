import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../data/models/price_record_model.dart';
import '../data/repositories/price_repository.dart';
import '../domain/price/price_calculator.dart';
import '../services/location_service.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';

class ProductDetailSheet extends ConsumerStatefulWidget {
  const ProductDetailSheet({super.key, required this.record});

  final PriceRecordModel record;

  @override
  ConsumerState<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<ProductDetailSheet> {
  static const int _communityRadiusMeters = 3000;
  final PriceRepository _priceRepository = PriceRepository();
  final PriceCalculator _priceCalculator = const PriceCalculator();
  final NumberFormat _priceFormat = NumberFormat.currency(
    symbol: '¥',
    decimalDigits: 0,
  );

  PriceRecordModel? _communityBestPrice;
  bool _isLoading = false;
  bool _locationUnavailable = false;
  String? _locationError;
  late final bool _isGuest;
  Position? _currentPosition;
  int? _communityLockedCount;
  ProviderSubscription<SubscriptionState>? _subscriptionSub;

  @override
  void initState() {
    super.initState();
    _isGuest = _priceRepository.isGuest;
    if (_isGuest) return;
    final subState = ref.read(subscriptionProvider);
    if (subState.isPro) {
      _fetchInsight();
    } else {
      _fetchLockedPreview();
    }
    _subscriptionSub = ref.listenManual<SubscriptionState>(
        subscriptionProvider, (previous, next) {
      final prevPro = previous?.isPro ?? false;
      if (prevPro != next.isPro) {
        if (next.isPro) {
          _fetchInsight();
        } else {
          if (mounted) {
            setState(() {
              _communityBestPrice = null;
              _isLoading = false;
            });
          }
          _fetchLockedPreview();
        }
      }
    });
  }

  @override
  void dispose() {
    _subscriptionSub?.close();
    super.dispose();
  }

  Future<void> _fetchInsight({bool highAccuracy = false}) async {
    final productName = widget.record.productName.trim();
    if (productName.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    debugPrint(
      '⏱️ [インサイト] 取得開始: ${stopwatch.elapsedMilliseconds}ms',
    );

    setState(() {
      _isLoading = true;
      _locationUnavailable = false;
      _locationError = null;
    });
    try {
      final position = await _obtainPosition(highAccuracy: highAccuracy);
      if (position == null) {
        if (!mounted) return;
        setState(() {
          _communityBestPrice = null;
          _isLoading = false;
          _locationUnavailable = true;
          _locationError = _locationError ??
              '位置情報が取得できませんでした。設定で位置情報をオンにしてください。';
        });
        return;
      }
      debugPrint(
        '⏱️ [インサイト] 位置取得: ${stopwatch.elapsedMilliseconds}ms',
      );

      final result = await _priceRepository.getNearbyCheapest(
        productName: productName,
        lat: position.latitude,
        lng: position.longitude,
        radiusMeters: _communityRadiusMeters,
        recentDays: 14,
      );
      debugPrint(
        '[インサイト] Supabase結果 lat=${position.latitude}, lng=${position.longitude} -> ${result != null ? 'hit' : 'empty'}',
      );
      debugPrint(
        '⏱️ [インサイト] APIレスポンス受信: ${stopwatch.elapsedMilliseconds}ms',
      );
      if (!mounted) return;
      setState(() {
        _communityBestPrice = result;
        _isLoading = false;
        _locationUnavailable = false;
        _locationError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _communityBestPrice = null;
        _isLoading = false;
        _locationUnavailable = true;
        _locationError ??= '再試行してください。';
      });
    }
  }

  Future<Position?> _obtainPosition({bool highAccuracy = false}) async {
    final result = await LocationRepository.instance.ensurePosition(
      highAccuracy: highAccuracy,
      cacheMaxAge: const Duration(minutes: 5),
    );
    final position = result.position;
    if (position != null) {
      _currentPosition = position;
      return position;
    }
    if (mounted) {
      setState(() {
        _locationError = LocationRepository.instance
            .messageForFailure(result.failure?.reason);
      });
    }
    if (result.failure?.reason == LocationFailureReason.serviceDisabled) {
      await LocationRepository.instance.openLocationSettings();
    }
    return null;
  }

  Future<void> _fetchLockedPreview() async {
    final productName = widget.record.productName.trim();
    final userUnitPrice = _priceCalculator.unitPrice(
      price: widget.record.price,
      quantity: widget.record.quantity,
    );
    if (productName.isEmpty || userUnitPrice == null) {
      return;
    }
    try {
      final position = await _obtainPosition();
      final count = await _priceRepository.countCheaperCommunityPrices(
        productName: productName,
        userUnitPrice: userUnitPrice,
        lat: position?.latitude,
        lng: position?.longitude,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _communityLockedCount = count;
        _locationUnavailable = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _communityLockedCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName =
        widget.record.productName.isNotEmpty ? widget.record.productName : '商品';
    final imageUrl = widget.record.imageUrl;
    final userPrice = widget.record.price;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _buildHeader(productName, imageUrl),
                  const SizedBox(height: 20),

                  _buildYourRecordCard(userPrice),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'コミュニティ情報',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF242424),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_communityRadiusMeters ~/ 1000}km圏内',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '現在地から約${_communityRadiusMeters ~/ 1000}km以内の最新価格を表示します。',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCommunityInsight(userPrice),
                  const SizedBox(height: 16),
                ],
              ),
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
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                        size: 32, color: Colors.grey),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child:
                        const Icon(Icons.image, size: 32, color: Colors.grey),
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
                  color: Color(0xFF242424),
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
    final shopName = widget.record.shopName ?? '店舗不明';
    final createdAt = widget.record.createdAt;
    final relative = createdAt != null ? _formatTimeAgo(createdAt) : '';
    final priceText = userPrice != null ? _priceFormat.format(userPrice) : '--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
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
                  fontSize: 24,
                  color: Color(0xFF242424),
                ),
              ),
              if (relative.isNotEmpty)
                Text(
                  relative,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.store, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                shopName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityInsight(double? userPrice) {
    final subState = ref.watch(subscriptionProvider);
    final isPro = subState.isPro;
    if (_isGuest || !isPro) {
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
              _locationError ?? 'タップして高精度で再試行します。',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed:
                  _isLoading ? null : () => _fetchInsight(highAccuracy: true),
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
        subtitle: '${_communityRadiusMeters ~/ 1000}km圏内で価格情報がまだありません。',
      );
    }

    final communityPrice = community.price;
    final communityUnitPrice = community.effectiveUnitPrice ??
        _priceCalculator.unitPrice(
          price: community.price,
          quantity: community.quantity,
        );

    final userUnitPrice = _priceCalculator.unitPrice(
      price: userPrice,
      quantity: widget.record.quantity,
    );
    final communityId = community.id;
    final userId = widget.record.id;

    final communityShop = community.shopName ?? '店舗不明';
    final communityDistance = community.distanceMeters;
    final communityDate = community.createdAt;

    // Compare Unit Prices for accurate "Best Price" logic
    final sameRecord = communityId != null &&
        userId != null &&
        communityId.toString() == userId.toString();
    final foundCheaper = communityUnitPrice != null &&
        userUnitPrice != null &&
        !sameRecord &&
        communityUnitPrice + 1e-6 < userUnitPrice;

    if (foundCheaper) {
      final subtitleParts = <String>[];
      final distanceText = _formatDistance(communityDistance);
      if (distanceText.isNotEmpty) subtitleParts.add(distanceText);
      final relative =
          communityDate != null ? _formatTimeAgo(communityDate) : null;
      if (relative != null) subtitleParts.add('$relativeに報告');

      final unitLabel =
          (community.unit ?? '').isNotEmpty ? '/${community.unit}' : '';
      final priceText =
          communityPrice != null ? _priceFormat.format(communityPrice) : '--';

      return _insightContainer(
        color: Colors.green.shade50,
        borderColor: Colors.green.shade200,
        title:
            'より安い価格を発見！ $priceText${unitLabel.isNotEmpty ? unitLabel : ""}（$communityShop）',
        icon: Icons.trending_down,
        subtitle: subtitleParts.isNotEmpty ? subtitleParts.join(' • ') : null,
      );
    }

    return _insightContainer(
      color: Colors.amber.shade50,
      borderColor: Colors.amber.shade200,
      title: 'あなたが最安値です！',
      icon: Icons.emoji_events,
      subtitle: '${_communityRadiusMeters ~/ 1000}km圏内により安い価格は見つかりませんでした。',
    );
  }

  Widget _buildLockedInsightCard(BuildContext context) {
    final count = _communityLockedCount;
    final hasCount = count != null && count > 0;
    final headline = hasCount
        ? 'コミュニティで$count件のより安い価格を発見！'
        : 'コミュニティ価格を解放しよう';
    final subtitle = hasCount
        ? 'Proで店舗名と価格の詳細を確認できます。'
        : 'Proにアップグレードして周辺の最安値をチェックしましょう。';
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
                'Pro限定',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
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
}
