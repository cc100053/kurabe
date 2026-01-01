import 'package:flutter/material.dart';

import '../data/models/price_record_model.dart';
import 'price_record_card.dart';

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

  @override
  Widget build(BuildContext context) {
    return PriceRecordCard(
      record: record,
      onTap: onTap,
      isCheapestOverride: isCheapestOverride,
    );
  }
}
