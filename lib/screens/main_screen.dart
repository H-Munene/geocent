import 'package:flutter/cupertino.dart';
import 'map_screen.dart';
import 'messages_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.map),
            activeIcon: Icon(CupertinoIcons.map_fill),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble_2),
            activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_square),
            activeIcon: Icon(CupertinoIcons.chart_bar_square_fill),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            activeIcon: Icon(CupertinoIcons.person_fill),
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
