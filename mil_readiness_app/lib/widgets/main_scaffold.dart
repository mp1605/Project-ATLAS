import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: child,
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location.startsWith('/readiness')) currentIndex = 1;
    else if (location.startsWith('/analytics')) currentIndex = 2;
    // else if (location.startsWith('/log-activity')) currentIndex = 3;
    else if (location.startsWith('/settings')) currentIndex = 3;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.glassBorder.withOpacity(0.1))),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: AppTheme.bgDark.withOpacity(0.9),
        selectedItemColor: AppTheme.primaryCyan,
        unselectedItemColor: AppTheme.textGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), activeIcon: Icon(Icons.insights), label: 'READINESS'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'ANALYTICS'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'SETTINGS'),
        ],
        onTap: (index) {
          switch (index) {
            case 0: context.go('/home'); break;
            case 1: context.go('/readiness'); break;
            case 2: context.go('/analytics'); break;
            case 3: context.go('/settings'); break;
          }
        },
      ),
    );
  }
}
