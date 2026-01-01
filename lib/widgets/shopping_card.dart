import 'package:flutter/material.dart';

import '../data/models/price_record_model.dart';
import 'price_record_card.dart';

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
    return PriceRecordCard(
      record: record,
      onTap: onTap,
      isCheapestOverride: isCheapestOverride,
    );
  }
}
