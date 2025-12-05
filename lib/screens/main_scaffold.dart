import 'package:flutter/material.dart';

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
        notchMargin: 8.0,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // Timeline Tab (Left)
              Expanded(
                child: _buildNavItem(
                  icon: Icons.history,
                  label: 'タイムライン',
                  index: 0,
                ),
              ),
              // Spacer for FAB (Center)
              const SizedBox(width: 80),
              // Catalog Tab (Right of FAB)
              Expanded(
                child: _buildNavItem(
                  icon: Icons.inventory_2_outlined,
                  label: '商品',
                  index: 1,
                ),
              ),
              // Profile Tab (Far Right)
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline,
                  label: 'マイページ',
                  index: 2,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddEditScreen()));
          setState(() {});
        },
        elevation: 4,
        tooltip: '記録を追加',
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? colorScheme.primary : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? colorScheme.primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
