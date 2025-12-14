import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../screens/add_edit_screen.dart';
import '../main.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/shopping_list_screen.dart';
import 'tabs/timeline_tab.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ProfileTabState> _profileTabKey =
      GlobalKey<ProfileTabState>();
  int _currentIndex = 0;
  late final AnimationController _fabAnimController;
  late final Animation<double> _fabScaleAnim;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const TimelineTab(),
      const CatalogTab(),
      const ShoppingListScreen(),
      ProfileTab(key: _profileTabKey),
    ];
    _fabAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    HapticFeedback.lightImpact();
    if (index == 3) {
      _profileTabKey.currentState?.refreshStats();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
      floatingActionButton: _buildFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      extendBody: true,
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 20,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withAlpha(26),
      clipBehavior: Clip.none,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 92,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        icon: PhosphorIcons.house(PhosphorIconsStyle.regular),
                        activeIcon:
                            PhosphorIcons.house(PhosphorIconsStyle.fill),
                        label: 'ホーム',
                        index: 0,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        icon: PhosphorIcons.squaresFour(
                            PhosphorIconsStyle.regular),
                        activeIcon:
                            PhosphorIcons.squaresFour(PhosphorIconsStyle.fill),
                        label: 'カタログ',
                        index: 1,
                      ),
                    ),
                  ],
                ),
              ),
              // Center gap reserved for FAB notch to enforce 2-1-2 symmetry
              const SizedBox(width: 88),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        icon: PhosphorIcons.checkSquare(
                            PhosphorIconsStyle.regular),
                        activeIcon:
                            PhosphorIcons.checkSquare(PhosphorIconsStyle.fill),
                        label: 'リスト',
                        index: 2,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        icon: PhosphorIcons.user(PhosphorIconsStyle.regular),
                        activeIcon: PhosphorIcons.user(PhosphorIconsStyle.fill),
                        label: 'マイページ',
                        index: 3,
                      ),
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

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final mediaQuery = MediaQuery.of(context);
    final clampedTextScaler =
        mediaQuery.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.0);

    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with scale animation
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? KurabeColors.primary
                    : KurabeColors.textTertiary,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            // Label with fade animation
            MediaQuery(
              data: mediaQuery.copyWith(textScaler: clampedTextScaler),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? KurabeColors.primary
                      : KurabeColors.textTertiary,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Active indicator pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 3,
              width: isSelected ? 20 : 0,
              decoration: BoxDecoration(
                color: KurabeColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _fabAnimController.forward(),
      onTapUp: (_) {
        _fabAnimController.reverse();
        _navigateToScan();
      },
      onTapCancel: () => _fabAnimController.reverse(),
      child: ScaleTransition(
        scale: _fabScaleAnim,
        child: Container(
          height: 68,
          width: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                KurabeColors.primary,
                KurabeColors.primaryLight,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: KurabeColors.primary.withAlpha(77), // ~30% opacity
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: KurabeColors.primary.withAlpha(38), // ~15% opacity
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              PhosphorIcons.scan(PhosphorIconsStyle.bold),
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToScan() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AddEditScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (result != null) {
      _profileTabKey.currentState?.refreshStats();
    }
    if (mounted) setState(() {});
  }
}
