import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_auth_service.dart';
import '../services/local_secure_store.dart';
import '../screens/lock_screen.dart';
import '../config/security_config.dart';

/// App-level wrapper that enforces biometric lock
/// 
/// Monitors app lifecycle and shows lock screen when session expires
/// Wraps the entire app to intercept all navigation
class AppLockWrapper extends StatefulWidget {
  final Widget child;
  
  const AppLockWrapper({
    super.key,
    required this.child,
  });
  
  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  final _biometricService = BiometricAuthService.instance;
  bool _isLocked = true;
  bool _isInitialized = false;
  
  // Key for detecting fresh install (stored in SharedPreferences which gets deleted with app)
  static const String _freshInstallKey = 'app_has_launched_before';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  /// Initialize biometric service and check lock state
  Future<void> _initialize() async {
    // Check for fresh install using SharedPreferences (gets deleted with app uninstall)
    final prefs = await SharedPreferences.getInstance();
    final hasLaunchedBefore = prefs.getBool(_freshInstallKey) ?? false;
    
    if (!hasLaunchedBefore) {
      // This is a fresh install - clear any old Keychain data
      print('🆕 Fresh install detected - clearing old Keychain settings');
      
      // Clear old biometric settings from Keychain
      await _biometricService.clearBiometricSettings();
      
      // Also clear any old session data (user must sign in again after reinstall)
      await LocalSecureStore.instance.clearSession();
      
      // Mark that app has launched (so next time we know it's not fresh)
      await prefs.setBool(_freshInstallKey, true);
      
      // Don't lock - show login screen
      setState(() {
        _isLocked = false;
        _isInitialized = true;
      });
      return;
    }
    
    await _biometricService.initialize();
    
    // FIRST: Check if there's an active user session
    // If no user is signed in, don't require Face ID (show login instead)
    final activeEmail = await LocalSecureStore.instance.getActiveSessionEmail();
    if (activeEmail == null || activeEmail.isEmpty) {
      // No active session - don't lock, let user see login screen
      print('ℹ️ No active session - skipping biometric lock');
      setState(() {
        _isLocked = false;
        _isInitialized = true;
      });
      return;
    }
    
    // Check if user has completed biometric setup (made a choice)
    final hasCompletedSetup = await _biometricService.hasCompletedBiometricSetup();
    if (!hasCompletedSetup) {
      // User signed in but hasn't set up biometric yet - don't lock
      setState(() {
        _isLocked = false;
        _isInitialized = true;
      });
      return;
    }
    
    // Check if biometric is enabled and available
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    final biometricAvailable = await _biometricService.isBiometricAvailable();
    
    if (!biometricEnabled || !biometricAvailable) {
      // Biometric not enabled or not available - unlock app
      setState(() {
        _isLocked = false;
        _isInitialized = true;
      });
      return;
    }
    
    // Biometric is enabled AND user is signed in - check if app is currently locked
    setState(() {
      _isLocked = _biometricService.isLocked;
      _isInitialized = true;
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('📱 App lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App going to background
        _handleAppPaused();
        break;
        
      case AppLifecycleState.resumed:
        // App coming to foreground
        _handleAppResumed();
        break;
        
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App being terminated or hidden
        break;
    }
  }
  
  /// Handle app going to background
  void _handleAppPaused() {
    print('📱 App paused (backgrounded)');
    
    // If lock on background is enabled, lock immediately
    if (SecurityConfig.lockOnBackground) {
      _biometricService.lockApp();
      return;
    }
    
    // Otherwise, session timeout will handle it
    _biometricService.updateLastActivity();
  }
  
  /// Handle app coming to foreground
  Future<void> _handleAppResumed() async {
    print('📱 App resumed (foregrounded)');
    
    // Check if there's an active user session
    final activeEmail = await LocalSecureStore.instance.getActiveSessionEmail();
    if (activeEmail == null || activeEmail.isEmpty) {
      return; // No active session, don't lock
    }
    
    // Check if user has completed biometric setup
    final hasCompletedSetup = await _biometricService.hasCompletedBiometricSetup();
    if (!hasCompletedSetup) {
      return; // Setup not completed, don't lock
    }
    
    // Check if biometric is enabled
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    if (!biometricEnabled) {
      return; // Biometric not enabled, don't lock
    }
    
    // Check if session is still valid
    if (!_biometricService.isSessionValid()) {
      print('🔒 Session expired - locking app');
      setState(() {
        _isLocked = true;
      });
    }
  }
  
  /// Handle successful authentication
  void _onAuthenticationSuccess() {
    setState(() {
      _isLocked = false;
    });
    _biometricService.unlockApp();
  }
  
  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    // Show lock screen if locked
    if (_isLocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LockScreen(
          onAuthenticationSuccess: _onAuthenticationSuccess,
        ),
      );
    }
    
    // Show actual app if unlocked
    return widget.child;
  }
}
