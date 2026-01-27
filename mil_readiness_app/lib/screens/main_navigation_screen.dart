import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routes.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import 'readiness_dashboard_screen.dart';
import 'trends_screen.dart';
import 'analytics_screen.dart';
import 'manual_logging_hub_screen.dart';
import 'profile_screen.dart';
import '../services/live_sync_controller.dart';
import '../services/local_secure_store.dart';
import '../models/wearable_type.dart';
import '../adapters/health_adapter_factory.dart';

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
  LiveSyncController? _liveSync;
  
  @override
  void initState() {
    super.initState();
    _initializeLiveSync();
    
    _screens = [
      ReadinessDashboardScreen(session: widget.session), // index 0: Home
      TrendsScreen(session: widget.session),           // 1: Trends
      const AnalyticsScreen(),                         // 2: Analytics
      ManualLoggingHubScreen(session: widget.session), // 3: Log
      ProfileScreen(session: widget.session),          // 4: Profile
    ];
  }

  Future<void> _initializeLiveSync() async {
    final email = widget.session.email ?? '';
    if (email.isEmpty) return;

    final selectedWearableName = await LocalSecureStore.instance.getSelectedWearableFor(email);
    final wearableType = selectedWearableName != null
        ? WearableType.values.byName(selectedWearableName)
        : WearableType.appleWatch;

    final adapter = HealthAdapterFactory.createAdapter(wearableType);

    _liveSync = LiveSyncController(
      healthAdapter: adapter,
      store: LocalSecureStore.instance,
      email: email,
      interval: const Duration(seconds: 60),
      // Use the standard 10m window, logic inside controller/adapter handles overlaps/daily
      window: const Duration(minutes: 10),
    );

    _liveSync!.start();
    widget.session.liveSync = _liveSync; // Store in session for global access
    print('✅ App-wide LiveSync started from MainNavigationScreen');
    
    // Update screens with the new liveSync instance
    setState(() {
      _screens[0] = ReadinessDashboardScreen(session: widget.session);
    });
  }

  @override
  void dispose() {
    _liveSync?.stop();
    super.dispose();
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
