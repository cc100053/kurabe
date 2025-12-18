import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/price_record_model.dart';
import 'product_detail_sheet.dart';

class ShoppingCard extends StatelessWidget {
  const ShoppingCard({
    super.key,
    required this.record,
    this.onTap,
    this.isCheapestOverride,
  });

  final PriceRecordModel record;
  final VoidCallback? onTap;
  final bool? isCheapestOverride;

  @override
  Widget build(BuildContext context) {
    final productName =
        record.productName.isNotEmpty ? record.productName : '商品名不明';
    final shopName = record.shopName ?? '店舗不明';
    final price = record.price;
    final isBest = isCheapestOverride ?? (record.isBestPrice ?? false);
    final confirmationCount = record.confirmationCount ?? 0;
    final imageUrl = record.imageUrl;
    final createdAt = record.createdAt?.toLocal();
    final dateText = createdAt != null
        ? DateFormat('MM/dd (E)', 'ja_JP').format(createdAt)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap ??
            () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProductDetailSheet(record: record),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        dateText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (confirmationCount > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$confirmationCount人確認',
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        shopName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, _) =>
                                  Container(color: Colors.grey.shade200),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
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
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (price != null)
                          Text(
                            '¥${price.round()}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (isBest)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('🟢 安い'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
