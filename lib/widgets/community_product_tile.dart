import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  final Map<String, dynamic> record;
  final VoidCallback? onTap;
  final bool? isCheapestOverride;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Extract data from record
    final productName = record['product_name'] as String? ?? '商品名不明';
    final shopName = record['shop_name'] as String? ?? '店舗不明';
    final price = (record['price'] as num?)?.toInt();
    final isCheapest = isCheapestOverride ?? record['is_best_price'] == true;
    final confirmationCount =
        (record['confirmation_count'] as num?)?.toInt() ?? 0;
    final imageUrl = record['image_url'] as String?;
    
    // Calculate unit price
    final unitPrice = _calculateUnitPrice(record);
    
    // Check if tax is included (handle both bool and int types)
    final taxIncludedValue = record['is_tax_included'];
    final isTaxIncluded = taxIncludedValue is bool 
        ? taxIncludedValue 
        : (taxIncludedValue is num ? taxIncludedValue.toInt() == 1 : false);
    
    // Calculate time ago
    final timeAgo = _calculateTimeAgo(record);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCheapest
              ? const Color(0xFFFF3B30).withAlpha((0.3 * 255).round())
              : colorScheme.outlineVariant,
          width: isCheapest ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ??
            () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProductDetailSheet(record: record),
              );
            },
        borderRadius: BorderRadius.circular(16),
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

                    // Metadata Row (Shop + Time + Social Proof)
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
    );
  }

  /// Product image with rounded corners and error handling
  Widget _buildProductImage(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 32,
                  color: Colors.grey[400],
                ),
              ),
      ),
    );
  }

  /// Product name with 2-line ellipsis
  Widget _buildProductName(String productName, TextTheme textTheme) {
    return Text(
      productName,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: const Color(0xFF1A1A1A),
        letterSpacing: -0.2,
      ),
    );
  }

  /// Elegant "最安" badge with gradient background
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
            color:
                const Color(0xFFFF3B30).withAlpha((0.3 * 255).round()),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        '最安',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
          height: 1.0,
        ),
      ),
    );
  }

  /// Hero price section with unit price and tax badge
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
        // Main Price (Hero)
        Text(
          '¥${_formatPrice(price)}',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: isCheapest
                ? const Color(0xFFFF3B30)
                : const Color(0xFF1A1A1A),
            letterSpacing: -1.0,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 6),
        
        // Tax Included Badge
        if (isTaxIncluded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '税込',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                height: 1.0,
              ),
            ),
          ),
        const SizedBox(width: 8),

        // Unit Price (Supporting)
        Text(
          unitPrice,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Metadata row with shop, time, and social proof
  Widget _buildMetadataRow(
    String shopName,
    String timeAgo,
    int confirmationCount,
    TextTheme textTheme,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Shop Icon + Name
        _buildMetadataChip(
          icon: Icons.store_outlined,
          label: shopName,
          textTheme: textTheme,
        ),

        // Time Ago
        _buildMetadataChip(
          icon: Icons.access_time_outlined,
          label: timeAgo,
          textTheme: textTheme,
        ),

        // Social Proof (if count > 1)
        if (confirmationCount > 1) _buildSocialProofChip(confirmationCount),
      ],
    );
  }

  /// Metadata chip with icon and label
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
          size: 15,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  /// Social proof chip with check icon and count
  Widget _buildSocialProofChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF34C759).withAlpha((0.4 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 14,
            color: Color(0xFF34C759),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF34C759),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate unit price string
  String _calculateUnitPrice(Map<String, dynamic> record) {
    final explicitUnitPrice = (record['unit_price'] as num?)?.toDouble();
    final unit = (record['unit'] as String?) ?? '';
    
    if (explicitUnitPrice != null) {
      final unitLabel = unit.isNotEmpty ? unit : '単価';
      return '(¥${explicitUnitPrice.toStringAsFixed(1)}/$unitLabel)';
    }

    final price = (record['price'] as num?)?.toDouble();
    final quantity = (record['quantity'] as num?)?.toDouble() ?? 1;
    
    if (price != null && quantity > 0) {
      final unitPriceValue = price / quantity;
      final unitLabel = unit.isNotEmpty ? unit : '単価';
      return '(¥${unitPriceValue.toStringAsFixed(1)}/$unitLabel)';
    }

    return '';
  }

  /// Calculate time ago string
  String _calculateTimeAgo(Map<String, dynamic> record) {
    final createdAtRaw = record['created_at'] as String?;
    if (createdAtRaw == null) return '';

    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
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

  /// Format price with thousands separator
  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
