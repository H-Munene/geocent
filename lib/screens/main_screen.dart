import 'package:flutter/cupertino.dart';
import 'map_screen.dart';
import 'messages_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import '../utils/icons.dart';

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  final CupertinoTabController _tabController = CupertinoTabController();

  void switchToTab(int index) {
    _tabController.index = index;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      key: mainScreenKey,
      controller: _tabController,
      tabBar: CupertinoTabBar(
        iconSize: 25,
        backgroundColor: CupertinoColors.white,
        items: [
          BottomNavigationBarItem(
            icon: pin,
            activeIcon: pinActive,
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: unmap,
            activeIcon: unmapActive,
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.chart_bar_square),
            activeIcon: const Icon(CupertinoIcons.chart_bar_square_fill),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: const Icon(CupertinoIcons.person_circle),
            activeIcon: const Icon(CupertinoIcons.person_circle_fill),
            label: 'Profile',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return const MapScreen();
              case 1:
                return const MessagesScreen();
              case 2:
                return const AnalyticsScreen();
              case 3:
                return const ProfileScreen();
              default:
                return const MapScreen();
            }
          },
        );
      },
    );
  }
}
