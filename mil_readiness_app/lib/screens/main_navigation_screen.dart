import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routes.dart';
import '../theme/app_theme.dart';
import 'readiness_dashboard_screen.dart';
import 'trends_screen.dart';
import 'analytics_screen.dart';
import 'manual_logging_hub_screen.dart';
import 'profile_screen.dart';

/// Main navigation wrapper with unified bottom navigation
/// Single source of truth for app navigation
class MainNavigationScreen extends StatefulWidget {
  final SessionController session;
  
  const MainNavigationScreen({super.key, required this.session});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      const ReadinessDashboardScreen(),                // 0: Home
      TrendsScreen(session: widget.session),           // 1: Trends
      const AnalyticsScreen(),                         // 2: Analytics
      ManualLoggingHubScreen(session: widget.session), // 3: Log
      ProfileScreen(session: widget.session),          // 4: Profile
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // Haptic feedback
          HapticFeedback.selectionClick();
        },
        backgroundColor: AppTheme.bgDark.withOpacity(0.95),
        indicatorColor: AppTheme.primaryCyan.withOpacity(0.2),
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Trends',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
