import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CategoryVisual {
  CategoryVisual({
    required this.color,
    required this.gradientEnd,
    required this.icon,
    this.weight,
  });

  final Color color;
  final Color gradientEnd;
  final IconData icon;
  final double? weight;
}

/// Shared category visuals used across Catalog and Add/Edit screens.
final Map<String, CategoryVisual> kCategoryVisuals = {
  // Fresh / Perishables
  '野菜': CategoryVisual(
    color: const Color(0xFFE8F5E9),
    gradientEnd: const Color(0xFFC8E6C9),
    icon: PhosphorIcons.carrot(PhosphorIconsStyle.fill),
  ),
  '果物': CategoryVisual(
    color: const Color(0xFFFFEBEE),
    gradientEnd: const Color(0xFFFFCDD2),
    icon: PhosphorIcons.orangeSlice(PhosphorIconsStyle.fill),
  ),
  '精肉': CategoryVisual(
    color: const Color(0xFFFFE5E0),
    gradientEnd: const Color(0xFFFFCCBC),
    icon: LucideIcons.beef,
  ),
  '鮮魚': CategoryVisual(
    color: const Color(0xFFE3F2FD),
    gradientEnd: const Color(0xFFBBDEFB),
    icon: PhosphorIcons.fishSimple(PhosphorIconsStyle.fill),
  ),
  '惣菜': CategoryVisual(
    color: const Color(0xFFFFF3E0),
    gradientEnd: const Color(0xFFFFE0B2),
    icon: Symbols.bento,
    weight: 600,
  ),
  '卵': CategoryVisual(
    color: const Color(0xFFFFF8E1),
    gradientEnd: const Color(0xFFFFECB3),
    icon: PhosphorIcons.egg(PhosphorIconsStyle.fill),
  ),
  '乳製品': CategoryVisual(
    color: const Color(0xFFE8F0FE),
    gradientEnd: const Color(0xFFD0E1FD),
    icon: PhosphorIcons.cheese(PhosphorIconsStyle.fill),
  ),
  '豆腐・納豆・麺': CategoryVisual(
    color: const Color(0xFFE0F2F1),
    gradientEnd: const Color(0xFFB2DFDB),
    icon: LucideIcons.soup,
  ),
  // Staples & Pantry
  'パン': CategoryVisual(
    color: const Color(0xFFFFF0D5),
    gradientEnd: const Color(0xFFFFE4B5),
    icon: PhosphorIcons.bread(PhosphorIconsStyle.fill),
  ),
  '米・穀物': CategoryVisual(
    color: const Color(0xFFF7E9D7),
    gradientEnd: const Color(0xFFEDD9BD),
    icon: PhosphorIcons.grains(PhosphorIconsStyle.fill),
  ),
  '調味料': CategoryVisual(
    color: const Color(0xFFFFF3E0),
    gradientEnd: const Color(0xFFFFE0B2),
    icon: PhosphorIcons.drop(PhosphorIconsStyle.fill),
  ),
  'インスタント': CategoryVisual(
    color: const Color(0xFFFCE4EC),
    gradientEnd: const Color(0xFFF8BBD9),
    icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
  ),
  // Drinks & Snacks
  '飲料': CategoryVisual(
    color: const Color(0xFFE0F7FA),
    gradientEnd: const Color(0xFFB2EBF2),
    icon: PhosphorIcons.coffee(PhosphorIconsStyle.fill),
  ),
  'お酒': CategoryVisual(
    color: const Color(0xFFF3E5F5),
    gradientEnd: const Color(0xFFE1BEE7),
    icon: PhosphorIcons.beerStein(PhosphorIconsStyle.fill),
  ),
  'お菓子': CategoryVisual(
    color: const Color(0xFFFFF0F5),
    gradientEnd: const Color(0xFFFFE4EC),
    icon: PhosphorIcons.cookie(PhosphorIconsStyle.fill),
  ),
  // Others
  '冷凍食品': CategoryVisual(
    color: const Color(0xFFE0F2FF),
    gradientEnd: const Color(0xFFBDDEFF),
    icon: PhosphorIcons.snowflake(PhosphorIconsStyle.fill),
  ),
  '日用品': CategoryVisual(
    color: const Color(0xFFF5F5F5),
    gradientEnd: const Color(0xFFE0E0E0),
    icon: PhosphorIcons.sprayBottle(PhosphorIconsStyle.fill),
  ),
  'その他': CategoryVisual(
    color: const Color(0xFFECEFF1),
    gradientEnd: const Color(0xFFCFD8DC),
    icon: PhosphorIcons.dotsThree(PhosphorIconsStyle.fill),
  ),
};
