import 'package:flutter/material.dart';

import '../main.dart';

class PriceSummaryCard extends StatelessWidget {
  const PriceSummaryCard({
    super.key,
    required this.finalTaxedTotal,
    required this.unitPrice,
    required this.quantity,
  });

  final double? finalTaxedTotal;
  final double? unitPrice;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    if (finalTaxedTotal == null && unitPrice == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: KurabeColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (finalTaxedTotal != null) ...[
            Text(
              '税込 ¥${finalTaxedTotal!.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: KurabeColors.primary,
              ),
            ),
          ],
          if (unitPrice != null && quantity > 1) ...[
            const SizedBox(width: 12),
            Text(
              '(@¥${unitPrice!.toStringAsFixed(0)})',
              style: const TextStyle(
                fontSize: 13,
                color: KurabeColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
