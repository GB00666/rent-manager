import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'tenants_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';

/// Lets any descendant widget request a tab switch, e.g. Home's
/// "See All" button jumping to the Tenants tab.
class TabController2 extends InheritedWidget {
  final ValueChanged<int> switchTab;

  const TabController2({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static TabController2? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabController2>();
  }

  @override
  bool updateShouldNotify(TabController2 oldWidget) =>
      switchTab != oldWidget.switchTab;
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // Keep state alive across tab switches.
  final List<Widget> _screens = const [
    HomeScreen(),
    TenantsScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  void switchTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return TabController2(
      switchTab: switchTab,
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: _BottomNav(
          currentIndex: _index,
          onTap: switchTab,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (_NavItem(Icons.home_rounded, 'Home')),
      (_NavItem(Icons.groups_rounded, 'Tenants')),
      (_NavItem(Icons.bar_chart_rounded, 'Reports')),
      (_NavItem(Icons.person_rounded, 'Profile')),
    ];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = i == currentIndex;
            final item = items[i];
            return InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textGrey,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}
