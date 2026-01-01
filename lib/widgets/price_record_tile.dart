import 'package:flutter/material.dart';

import '../data/models/price_record_model.dart';
import 'community_product_tile.dart';

class PriceRecordTile extends StatelessWidget {
  const PriceRecordTile({
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
    return CommunityProductTile(
      record: record,
      onTap: onTap,
      isCheapestOverride: isCheapestOverride,
    );
  }
}
