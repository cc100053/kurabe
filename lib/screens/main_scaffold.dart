import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../screens/add_edit_screen.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/timeline_tab.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final _tabs = const [TimelineTab(), CatalogTab(), ProfileTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10.0,
        height: 72, // Taller, premium feel
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 10,
        shadowColor: Colors.black.withAlpha((0.1 * 255).round()),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Group
            Row(
              children: [
                _buildNavItem(
                  icon: PhosphorIcons.house(PhosphorIconsStyle.bold),
                  activeIcon: PhosphorIcons.house(PhosphorIconsStyle.fill),
                  label: 'タイムライン',
                  index: 0,
                ),
                const SizedBox(width: 24), // Spacing
                _buildNavItem(
                  icon: PhosphorIcons.squaresFour(PhosphorIconsStyle.bold),
                  activeIcon: PhosphorIcons.squaresFour(PhosphorIconsStyle.fill),
                  label: 'カタログ',
                  index: 1,
                ),
              ],
            ),
            
            // Right Group
            _buildNavItem(
              icon: PhosphorIcons.user(PhosphorIconsStyle.bold),
              activeIcon: PhosphorIcons.user(PhosphorIconsStyle.fill),
              label: 'プロフィール',
              index: 2,
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.tertiary, // Use secondary/tertiary for gradient
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withAlpha((0.4 * 255).round()),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
          child: FloatingActionButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditScreen()),
              );
              setState(() {});
            },
            elevation: 0,
            backgroundColor: Colors.transparent, // Transparent to show gradient
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            tooltip: '価格をスキャン',
            child: Icon(
              PhosphorIcons.scan(PhosphorIconsStyle.fill),
              size: 30,
            ),
          ),
        ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      extendBody: true, // For transparency effects if needed, though BottomAppBar is solid
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? colorScheme.primary : const Color(0xFF9E9E9E),
              size: 26,
            ),
            // Optional: Small dot indicator instead of text label for minimal look
            // Or keep the text but make it subtle. User asked for high legibility.
            // Let's stick to just the icon change as per "Modern Japanese" often minimal.
            // But user might want labels. I'll add a tiny dot for selected state.
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              width: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
