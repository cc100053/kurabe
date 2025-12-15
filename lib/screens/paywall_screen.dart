import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../main.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  ProviderSubscription<SubscriptionState>? _sub;
  int _selectedPlanIndex = 1; // Default to monthly (middle option)

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<SubscriptionState>(
      subscriptionProvider,
      (previous, next) {
        final error = next.error;
        if (error != null && error.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
        if (previous?.isPro == false && next.isPro && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proを有効化しました！🎉')),
          );
          Navigator.of(context).maybePop();
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);
    final subscriptionService = SubscriptionService();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              
              // Close button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // App Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: KurabeColors.primary.withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/icon_square.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            KurabeColors.primary,
                            KurabeColors.primary.withAlpha(180),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title with highlight
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: KurabeColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    const TextSpan(text: 'カイログ '),
                    WidgetSpan(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: KurabeColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: KurabeColors.primary.withAlpha(50),
                            width: 2,
                          ),
                        ),
                        child: const Text(
                          'Pro',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: KurabeColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'コミュニティの価格情報で\nもっとお得に買い物しよう',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Award badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIcons.crown(PhosphorIconsStyle.fill),
                      size: 18,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '毎月の節約に',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'お役立ち',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KurabeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      PhosphorIcons.crown(PhosphorIconsStyle.fill),
                      size: 18,
                      color: Colors.amber.shade700,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Testimonial Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'お買い物上手の味方',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: KurabeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Star rating
                    Row(
                      children: List.generate(
                        5,
                        (index) => const Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: Color(0xFFFFB800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '「いつも行くスーパーで買っていた牛乳、近くの別のお店の方が50円も安いとわかりました。毎週の買い物で少しずつ節約できています！」',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '節約主婦ママ',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Pricing tiers
              Row(
                children: [
                  _buildPricingTier(
                    index: 0,
                    duration: '1',
                    unit: '週間',
                    price: '¥150',
                    isSelected: _selectedPlanIndex == 0,
                    isBestValue: false,
                  ),
                  const SizedBox(width: 12),
                  _buildPricingTier(
                    index: 1,
                    duration: '1',
                    unit: 'ヶ月',
                    price: '¥350',
                    isSelected: _selectedPlanIndex == 1,
                    isBestValue: true,
                  ),
                  const SizedBox(width: 12),
                  _buildPricingTier(
                    index: 2,
                    duration: '∞',
                    unit: '買い切り',
                    price: '¥1,200',
                    isSelected: _selectedPlanIndex == 2,
                    isBestValue: false,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: subState.isLoading || subState.isPro
                      ? null
                      : () => notifier.purchase(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KurabeColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: subState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          subState.isPro ? 'Pro 有効中 ✓' : '続ける',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Restore purchases
              TextButton(
                onPressed: subState.isLoading ? null : () => notifier.restore(),
                child: Text(
                  '購入を復元',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: KurabeColors.primary,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Terms and Privacy
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLinkButton(
                    '利用規約',
                    () => _showTermsDialog(context),
                  ),
                  Text(
                    ' • ',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  _buildLinkButton(
                    'プライバシー',
                    () => _showTermsDialog(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingTier({
    required int index,
    required String duration,
    required String unit,
    required String price,
    required bool isSelected,
    required bool isBestValue,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlanIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? KurabeColors.accent : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? KurabeColors.accent : Colors.grey.shade200,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: KurabeColors.accent.withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  // Best value badge
                  if (isBestValue)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : KurabeColors.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: isSelected ? KurabeColors.accent : Colors.white,
                        ),
                      ),
                    ),
                  
                  // Duration
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : KurabeColors.textPrimary,
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withAlpha(200)
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Price
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : KurabeColors.accent,
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

  Widget _buildLinkButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('利用規約 / プライバシー'),
          content: const Text(
            'プライバシーポリシーと利用規約の詳細はアプリ内または公式サイトでご確認ください。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }
}
