import 'package:flutter/cupertino.dart';
import 'map_screen.dart';
import 'messages_screen.dart';
import 'budgets_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import '../utils/icons.dart';

import 'package:provider/provider.dart';
import '../services/spending_service.dart';

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  final CupertinoTabController _tabController = CupertinoTabController();

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (!mounted) return;
    // Reset search and filters in SpendingService when switching tabs
    context.read<SpendingService>().resetSearchAndFilters();
  }

  void switchToTab(int index) {
    _tabController.index = index;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final int actionableCount = spendingService.allTransactions
        .where((tx) => tx.latitude == null || tx.category == null)
        .length;

    Widget buildMessagesIcon(Widget iconWidget) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          if (actionableCount > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionableCount > 99 ? '99+' : '$actionableCount',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return CupertinoTabScaffold(
      key: mainScreenKey,
      controller: _tabController,
      tabBar: CupertinoTabBar(
        iconSize: 25,
        backgroundColor: CupertinoColors.white,
        border: null,
        activeColor: const Color(0xFF0071E3),
        items: [
          BottomNavigationBarItem(
            icon: pin,
            activeIcon: pinActive,
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: buildMessagesIcon(unmap),
            activeIcon: buildMessagesIcon(unmapActive),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_pie),
            activeIcon: Icon(CupertinoIcons.chart_pie_fill),
            label: 'Budgets',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_square),
            activeIcon: Icon(CupertinoIcons.chart_bar_square_fill),
            label: 'Analytics',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_circle),
            activeIcon: Icon(CupertinoIcons.person_circle_fill),
            label: 'Profile',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return Stack(
          children: [
            CupertinoTabView(
              builder: (context) {
                switch (index) {
                  case 0:
                    return const MapScreen();
                  case 1:
                    return const MessagesScreen();
                  case 2:
                    return const BudgetsScreen();
                  case 3:
                    return const AnalyticsScreen();
                  case 4:
                    return const ProfileScreen();
                  default:
                    return const MapScreen();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
