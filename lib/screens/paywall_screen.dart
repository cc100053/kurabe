import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../main.dart';
import '../providers/subscription_provider.dart';
import '../widgets/app_snackbar.dart';
import 'legal/legal_document_screen.dart';
import 'legal/legal_documents.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen>
    with SingleTickerProviderStateMixin {
  ProviderSubscription<SubscriptionState>? _sub;
  int _selectedPlanIndex = 1;
  static const List<String> _packageIds = ['monthly', 'annual'];
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _sub = ref.listenManual<SubscriptionState>(
      subscriptionProvider,
      (previous, next) {
        final error = next.error;
        if (error != null && error.isNotEmpty && mounted) {
          AppSnackbar.show(context, error, isError: true);
        }
        if (previous?.isPro == false && next.isPro && mounted) {
          AppSnackbar.show(context, 'Proを有効化しました！🎉');
          Navigator.of(context).maybePop();
        }
      },
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFEEF2F5),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header with gradient background
                _buildHeader(),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Features card with glassmorphism
                      _buildFeaturesCard(),

                      const SizedBox(height: 24),

                      // Pricing section
                      _buildPricingSection(),

                      const SizedBox(height: 24),

                      // CTA Button
                      _buildCTAButton(subState, notifier),

                      const SizedBox(height: 16),

                      // Restore & Terms
                      _buildFooterLinks(subState, notifier),

                      const SizedBox(height: 24),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            KurabeColors.primary,
            KurabeColors.primary.withAlpha(200),
            const Color(0xFF2BB5A1),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: KurabeColors.primary.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(15),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(10),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // App Icon with glow
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withAlpha(50),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/icon_inside.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white,
                          child: Icon(
                            Icons.shopping_cart,
                            size: 36,
                            color: KurabeColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'カイログ',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.crown(PhosphorIconsStyle.fill),
                            size: 16,
                            color: const Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Pro',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: KurabeColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'お得に買い物するための必須ツール',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(220),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Column(
      children: [
        // Section title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    KurabeColors.accent.withAlpha(100),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Icon(
                  PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                  color: KurabeColors.accent,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Proでできること',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KurabeColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    KurabeColors.accent.withAlpha(100),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Features card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Features
              _buildFeatureRow(
                PhosphorIcons.users(PhosphorIconsStyle.fill),
                'コミュニティの価格を閲覧',
                'みんなが投稿した最安値をチェック',
                KurabeColors.primary,
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill),
                'どこが最安か瞬時に検索',
                '商品名で近くのお店を一括比較',
                KurabeColors.success,
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                PhosphorIcons.prohibit(PhosphorIconsStyle.fill),
                '広告なしでサクサク',
                '快適な操作体験を実現',
                Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: KurabeColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Icon(
          PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
          color: KurabeColors.success,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildPricingSection() {
    return Column(
      children: [
        // Section title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    KurabeColors.primary.withAlpha(100),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'プランを選択',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KurabeColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    KurabeColors.primary.withAlpha(100),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pricing cards
        Row(
          children: [
            _buildPricingCard(
              index: 0,
              duration: '1',
              unit: 'ヶ月',
              price: '¥280',
              perMonth: '¥280/月',
              isSelected: _selectedPlanIndex == 0,
              badge: null,
            ),
            const SizedBox(width: 10),
            _buildPricingCard(
              index: 1,
              duration: '1',
              unit: '年',
              price: '¥2,800',
              perMonth: '¥233/月',
              isSelected: _selectedPlanIndex == 1,
              badge: '最安',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '初回14日無料トライアル',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: KurabeColors.primary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPricingCard({
    required int index,
    required String duration,
    required String unit,
    required String price,
    required String perMonth,
    required bool isSelected,
    String? badge,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlanIndex = index),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main card
            AspectRatio(
              aspectRatio: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected ? KurabeColors.accent : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? KurabeColors.accent : Colors.grey.shade200,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected 
                          ? KurabeColors.accent.withAlpha(40)
                          : Colors.black.withAlpha(5),
                      blurRadius: isSelected ? 12 : 8,
                      offset: Offset(0, isSelected ? 4 : 2),
                    ),
                  ],
                ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Duration
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 32,
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
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : KurabeColors.accent,
                      ),
                    ),

                    // Per month
                    Text(
                      perMonth,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white.withAlpha(180)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            
            // Floating badge
            if (badge != null)
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : KurabeColors.accent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? KurabeColors.accent : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTAButton(
    SubscriptionState subState,
    SubscriptionController notifier,
  ) {
    final packageId = _selectedPlanIndex >= 0 &&
            _selectedPlanIndex < _packageIds.length
        ? _packageIds[_selectedPlanIndex]
        : _packageIds.first;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            KurabeColors.accent,
            KurabeColors.accent.withAlpha(220),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: KurabeColors.accent.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: subState.isLoading || subState.isPro
            ? null
            : () => notifier.purchasePlan(packageId),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    subState.isPro
                        ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                        : PhosphorIcons.crown(PhosphorIconsStyle.fill),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subState.isPro ? 'Pro 有効中' : 'Proを始める',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooterLinks(
    SubscriptionState subState,
    SubscriptionController notifier,
  ) {
    return Column(
      children: [
        TextButton(
          onPressed: subState.isLoading ? null : () => notifier.restore(),
          child: const Text(
            '購入を復元',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: KurabeColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLinkButton('利用規約',
                () => _openLegalDocument(context, '利用規約', termsOfServiceText)),
            Text(' • ', style: TextStyle(color: Colors.grey.shade400)),
            _buildLinkButton(
                'プライバシー',
                () => _openLegalDocument(
                    context, 'プライバシー', privacyPolicyText)),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _openLegalDocument(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(title: title, body: body),
      ),
    );
  }
}
