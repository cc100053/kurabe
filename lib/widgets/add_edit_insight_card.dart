import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/add_edit/add_edit_state.dart';

class AddEditInsightCard extends StatelessWidget {
  const AddEditInsightCard({
    super.key,
    required this.insight,
    required this.isLoading,
    required this.isPro,
    required this.onUpgradeTap,
    required this.formatDistance,
  });

  final AddEditInsight insight;
  final bool isLoading;
  final bool isPro;
  final VoidCallback onUpgradeTap;
  final String Function(double) formatDistance;

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.travel_explore;
    Color iconColor = KurabeColors.textSecondary;
    Color bgColor = KurabeColors.divider;
    String title = '周辺の価格をチェックしよう';
    String? subtitle = '商品名と価格を入力すると比較が表示されます。';

    if (isLoading) {
      icon = Icons.search;
      iconColor = KurabeColors.textTertiary;
      bgColor = KurabeColors.divider;
      title = '周辺の価格を検索中...';
      subtitle = '少々お待ちください。';
    } else {
      switch (insight.status) {
        case InsightStatus.none:
          icon = Icons.add_circle_outline;
          iconColor = KurabeColors.primary;
          bgColor = KurabeColors.primary.withAlpha(20);
          title = '周辺に記録なし';
          subtitle = 'この商品の最初の投稿者になろう！';
          break;
        case InsightStatus.best:
          icon = Icons.emoji_events;
          iconColor = Colors.amber.shade700;
          bgColor = Colors.amber.shade100;
          title = (!isPro && insight.gatedMessage != null)
              ? '周辺に記録があります'
              : '周辺最安値！';
          if (insight.gatedMessage != null) {
            subtitle = insight.gatedMessage;
          } else if (insight.price != null && insight.shop != null) {
            final distance = insight.distanceMeters != null
                ? formatDistance(insight.distanceMeters!)
                : '';
            subtitle = '次点: ${insight.shop} ¥${insight.price!.round()} $distance';
          } else {
            subtitle = '他の店舗よりも安い価格です。';
          }
          break;
        case InsightStatus.found:
          icon = Icons.local_offer;
          iconColor = KurabeColors.success;
          bgColor = KurabeColors.success.withAlpha(20);
          title = (!isPro && insight.gatedMessage != null)
              ? '周辺に記録があります'
              : 'より安い価格を発見！';
          if (insight.gatedMessage != null) {
            subtitle = insight.gatedMessage;
          } else if (isPro) {
            final priceText =
                insight.price != null ? '¥${insight.price!.round()}' : '';
            final shopText = insight.shop ?? '';
            final distance = insight.distanceMeters != null
                ? formatDistance(insight.distanceMeters!)
                : '';
            subtitle = '$shopText $priceText $distance'.trim();
          } else {
            subtitle = 'Proにアップグレードして店舗と価格を確認しよう';
          }
          break;
        case InsightStatus.idle:
          break;
      }
    }

    final subtitleText = subtitle ?? ' ';
    final showUpgradeButton =
        !isPro && insight.status == InsightStatus.found && !isLoading;

    return SizedBox(
      height: 86,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KurabeColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KurabeColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showUpgradeButton) ...[
              const SizedBox(width: 8),
              AddEditProUpsellButton(onTap: onUpgradeTap),
            ],
          ],
        ),
      ),
    );
  }
}

class AddEditProUpsellButton extends StatelessWidget {
  const AddEditProUpsellButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          backgroundColor: KurabeColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: const Text(
          'Proを始める',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
