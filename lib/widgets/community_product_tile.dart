import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/models/price_record_model.dart';
import '../domain/price/price_calculator.dart';
import '../main.dart';
import 'product_detail_sheet.dart';

/// A premium tile widget for displaying community-sourced product price data.
/// Designed with Material 3 principles and Japanese consumer app aesthetics
/// (like PayPay, Rakuten, Mercari).
class CommunityProductTile extends StatelessWidget {
  const CommunityProductTile({
    super.key,
    required this.record,
    this.onTap,
    this.isCheapestOverride,
  });

  final PriceRecordModel record;
  final VoidCallback? onTap;
  final bool? isCheapestOverride;
  static const PriceCalculator _calculator = PriceCalculator();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Extract data from record
    final productName = record.productName.isNotEmpty
        ? record.productName
        : '商品名不明';
    final shopName = record.shopName ?? '店舗不明';
    final price = record.price?.toInt();
    final isCheapest =
        isCheapestOverride ?? (record.isBestPrice ?? false);
    final confirmationCount = record.confirmationCount ?? 0;
    final imageUrl = record.imageUrl;

    // Calculate unit price
    final unitPrice = _calculateUnitPrice(record);

    // Check if tax is included
    final isTaxIncluded = record.isTaxIncluded ?? false;

    // Calculate time ago
    final timeAgo = _calculateTimeAgo(record);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KurabeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCheapest
              ? KurabeColors.error.withAlpha(77)
              : KurabeColors.border,
          width: isCheapest ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCheapest
                ? KurabeColors.error.withAlpha(20)
                : Colors.black.withAlpha(8),
            blurRadius: isCheapest ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  showDragHandle: false,
                  builder: (_) => ProductDetailSheet(record: record),
                );
              },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                _buildProductImage(imageUrl),
                const SizedBox(width: 14),

                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name Row with Cheapest Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildProductName(productName, textTheme),
                          ),
                          if (isCheapest) ...[
                            const SizedBox(width: 8),
                            _buildCheapestBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Price Hero Section
                      if (price != null)
                        _buildPriceSection(
                          price,
                          unitPrice,
                          isCheapest,
                          isTaxIncluded,
                          textTheme,
                        ),
                      const SizedBox(height: 12),

                      // Metadata Row
                      _buildMetadataRow(
                        shopName,
                        timeAgo,
                        confirmationCount,
                        textTheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: KurabeColors.divider,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  color: KurabeColors.divider,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: KurabeColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  return Container(
                    color: KurabeColors.divider,
                    child: Icon(
                      PhosphorIcons.shoppingBag(PhosphorIconsStyle.duotone),
                      size: 32,
                      color: KurabeColors.textTertiary,
                    ),
                  );
                },
              )
            : Container(
                color: KurabeColors.divider,
                child: Icon(
                  PhosphorIcons.image(PhosphorIconsStyle.duotone),
                  size: 32,
                  color: KurabeColors.textTertiary,
                ),
              ),
      ),
    );
  }

  Widget _buildProductName(String productName, TextTheme textTheme) {
    return Text(
      productName,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: KurabeColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildCheapestBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFFF6B58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B30).withAlpha(77),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.fire(PhosphorIconsStyle.fill),
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          const Text(
            '最安',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(
    int price,
    String unitPrice,
    bool isCheapest,
    bool isTaxIncluded,
    TextTheme textTheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Currency symbol
        Text(
          '¥',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isCheapest ? KurabeColors.error : KurabeColors.textPrimary,
            height: 1.0,
          ),
        ),
        // Main Price
        Text(
          _formatPrice(price),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: isCheapest ? KurabeColors.error : KurabeColors.textPrimary,
            letterSpacing: -1.0,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 8),

        // Tax Included Badge
        if (isTaxIncluded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: KurabeColors.divider,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '税込',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: KurabeColors.textSecondary,
                height: 1.0,
              ),
            ),
          ),

        // Unit Price
        if (unitPrice.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            unitPrice,
            style: textTheme.bodyMedium?.copyWith(
              color: KurabeColors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataRow(
    String shopName,
    String timeAgo,
    int confirmationCount,
    TextTheme textTheme,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Shop
        _buildMetadataChip(
          icon: PhosphorIcons.storefront(PhosphorIconsStyle.fill),
          label: shopName,
          textTheme: textTheme,
        ),

        // Time Ago
        if (timeAgo.isNotEmpty)
          _buildMetadataChip(
            icon: PhosphorIcons.clock(PhosphorIconsStyle.fill),
            label: timeAgo,
            textTheme: textTheme,
          ),

        // Social Proof
        if (confirmationCount > 1) _buildSocialProofChip(confirmationCount),
      ],
    );
  }

  Widget _buildMetadataChip({
    required IconData icon,
    required String label,
    required TextTheme textTheme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: KurabeColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: KurabeColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialProofChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: KurabeColors.success.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: KurabeColors.success.withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.checks(PhosphorIconsStyle.bold),
            size: 14,
            color: KurabeColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            '$count人確認',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: KurabeColors.success,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateUnitPrice(PriceRecordModel record) {
    final unitLabel = (record.unit ?? '').isNotEmpty ? record.unit! : '単価';
    final unitPriceValue = record.effectiveUnitPrice ??
        _calculator.unitPrice(price: record.price, quantity: record.quantity);
    if (unitPriceValue == null) return '';
    return '(¥${unitPriceValue.toStringAsFixed(1)}/$unitLabel)';
  }

  String _calculateTimeAgo(PriceRecordModel record) {
    final createdAt = record.createdAt?.toLocal();
    if (createdAt == null) return '';

    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return DateFormat('MM/dd', 'ja_JP').format(createdAt);
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
