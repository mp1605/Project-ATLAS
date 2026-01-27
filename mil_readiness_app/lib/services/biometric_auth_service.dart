import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/security_config.dart';

/// Biometric authentication service for app-level security
/// 
/// Manages Face ID/Touch ID authentication and session management
/// Implements app lifecycle monitoring for auto-lock functionality
class BiometricAuthService {
  // Singleton pattern
  BiometricAuthService._();
  static final BiometricAuthService instance = BiometricAuthService._();
  
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const _secureStorage = FlutterSecureStorage();
  
  // Session management
  DateTime? _lastActivityTime;
  bool _isLocked = true;
  bool _requiresSetup = false; // True when biometricSetupRequired=true but user hasn't configured
  
  // Storage keys
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keySessionTimeout = 'session_timeout_minutes';
  static const String _keyLastLockTime = 'last_lock_time';
  static const String _keyHasCompletedSetup = 'has_completed_biometric_setup';
  static const String _keyBiometricPromptShown = 'biometric_prompt_shown';
  
  // ============================================================================
  // BIOMETRIC AVAILABILITY
  // ============================================================================
  
  /// Check if biometric authentication is available on this device
  Future<bool> isBiometricAvailable() async {
    try {
      if (!SecurityConfig.features.biometricAuth) {
        return false;
      }
      
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      print('❌ Error checking biometric availability: $e');
      return false;
    }
  }
  
  /// Get available biometric types (Face ID, Touch ID, Fingerprint, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('❌ Error getting available biometrics: $e');
      return [];
    }
  }
  
  /// Get user-friendly name for biometric type
  String getBiometricTypeName() {
    if (Platform.isIOS) {
      return 'Face ID or Touch ID';
    } else {
      return 'Fingerprint';
    }
  }
  
  // ============================================================================
  // AUTHENTICATION
  // ============================================================================
  
  /// Authenticate user with biometrics
  /// Returns true if authentication succeeds
  Future<bool> authenticate({
    String? reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      final message = reason ?? SecurityConfig.biometricPromptMessage;
      
      // Use config-driven biometric policy:
      // enterpriseStrictBiometric=true → biometricOnly (no passcode fallback)
      // enterpriseStrictBiometric=false → allow OS passcode fallback
      final strictMode = SecurityConfig.enterpriseStrictBiometric;
      
      if (!SecurityConfig.isProduction) {
        print('🔐 Requesting biometric authentication (strict=$strictMode)...');
      }
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: message,
        options: AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: strictMode, // Config-driven!
        ),
      );
      
      if (authenticated) {
        if (!SecurityConfig.isProduction) {
          print('✅ Biometric authentication successful');
        }
        _isLocked = false;
        _lastActivityTime = DateTime.now();
        await _saveLastLockTime(null); // Clear lock time
      } else {
        if (!SecurityConfig.isProduction) {
          print('❌ Biometric authentication failed');
        }
      }
      
      return authenticated;
    } on PlatformException catch (e) {
      if (!SecurityConfig.isProduction) {
        print('❌ Biometric authentication error: ${e.code} - ${e.message}');
      }
      
      // Handle specific error cases
      switch (e.code) {
        case 'NotAvailable':
          // Biometric not available - behavior depends on config
          break;
        case 'NotEnrolled':
          // No biometrics enrolled
          break;
        case 'PasscodeNotSet':
          // Device passcode not set
          break;
        case 'LockedOut':
          // Too many failed attempts
          break;
      }
      
      return false;
    } catch (e) {
      if (!SecurityConfig.isProduction) {
        print('❌ Unexpected error during authentication: $e');
      }
      return false;
    }
  }
  
  // ============================================================================
  // SESSION MANAGEMENT
  // ============================================================================
  
  /// Check if current session is valid (not expired)
  bool isSessionValid() {
    if (!_isLocked && _lastActivityTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastActivityTime!);
      
      final timeout = getSessionTimeout();
      
      return elapsed < timeout;
    }
    
    return false;
  }
  
  /// Update last activity time (call on user interaction)
  void updateLastActivity() {
    if (!_isLocked) {
      _lastActivityTime = DateTime.now();
    }
  }
  
  /// Lock the app (requires re-authentication)
  Future<void> lockApp() async {
    print('🔒 Locking app...');
    _isLocked = true;
    _lastActivityTime = null;
    await _saveLastLockTime(DateTime.now());
  }
  
  /// Unlock the app (call after successful authentication)
  void unlockApp() {
    if (!SecurityConfig.isProduction) {
      print('🔓 App unlocked');
    }
    _isLocked = false;
    _requiresSetup = false;
    _lastActivityTime = DateTime.now();
  }
  
  /// Check if app is currently locked
  bool get isLocked => _isLocked;
  
  /// Check if mandatory biometric setup is required but not completed
  bool get requiresSetup => _requiresSetup;
  
  /// Get time remaining until session expires
  Duration? getTimeUntilExpiry() {
    if (_isLocked || _lastActivityTime == null) {
      return null;
    }
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastActivityTime!);
    final timeout = getSessionTimeout();
    final remaining = timeout - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  // ============================================================================
  // USER PREFERENCES
  // ============================================================================
  
  /// Check if biometric authentication is enabled by user
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
    return enabled == 'true';
  }
  
  /// Enable/disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
      key: _keyBiometricEnabled,
      value: enabled.toString(),
    );
    // Mark that setup has been completed (user made a choice)
    await _secureStorage.write(
      key: _keyHasCompletedSetup,
      value: 'true',
    );
    print('🔐 Biometric authentication ${enabled ? 'enabled' : 'disabled'}');
  }
  
  /// Check if user has completed biometric setup (made a choice to enable/disable)
  Future<bool> hasCompletedBiometricSetup() async {
    final completed = await _secureStorage.read(key: _keyHasCompletedSetup);
    return completed == 'true';
  }
  
  /// Check if the biometric enable prompt has been shown to user
  Future<bool> hasBiometricPromptBeenShown() async {
    final shown = await _secureStorage.read(key: _keyBiometricPromptShown);
    return shown == 'true';
  }
  
  /// Mark that the biometric prompt has been shown
  Future<void> markBiometricPromptShown() async {
    await _secureStorage.write(
      key: _keyBiometricPromptShown,
      value: 'true',
    );
  }
  
  /// Get session timeout duration
  Duration getSessionTimeout() {
    // Return configured timeout from SecurityConfig
    return SecurityConfig.sessionTimeout;
  }
  
  /// Set session timeout duration (save user preference)
  Future<void> setSessionTimeout(Duration timeout) async {
    await _secureStorage.write(
      key: _keySessionTimeout,
      value: timeout.inMinutes.toString(),
    );
    print('⏱️ Session timeout set to ${timeout.inMinutes} minutes');
  }
  
  /// Get last lock time
  Future<DateTime?> getLastLockTime() async {
    final timeStr = await _secureStorage.read(key: _keyLastLockTime);
    if (timeStr != null) {
      return DateTime.parse(timeStr);
    }
    return null;
  }
  
  /// Save last lock time
  Future<void> _saveLastLockTime(DateTime? time) async {
    if (time != null) {
      await _secureStorage.write(
        key: _keyLastLockTime,
        value: time.toIso8601String(),
      );
    } else {
      await _secureStorage.delete(key: _keyLastLockTime);
    }
  }
  
  // ============================================================================
  // INITIALIZATION
  // ============================================================================
  
  /// Initialize biometric service (call on app startup)
  /// 
  /// Lock behavior depends on config:
  /// - biometricSetupRequired=true: User MUST complete setup, cannot bypass
  /// - biometricSetupRequired=false: User can skip, app unlocks if not configured
  Future<void> initialize() async {
    if (!SecurityConfig.isProduction) {
      print('🔐 Initializing BiometricAuthService...');
    }
    
    // Check if user has completed biometric setup
    final hasCompletedSetup = await hasCompletedBiometricSetup();
    
    if (!hasCompletedSetup) {
      // First launch or user hasn't made a choice yet
      if (SecurityConfig.biometricSetupRequired) {
        // Mandatory setup: keep locked until user configures biometric
        if (!SecurityConfig.isProduction) {
          print('🔒 Biometric setup required but not completed - app locked');
        }
        _isLocked = true;
        _requiresSetup = true;
        return;
      } else {
        // Optional setup: allow access without biometric
        if (!SecurityConfig.isProduction) {
          print('ℹ️ First launch or setup not completed - app unlocked');
        }
        _isLocked = false;
        return;
      }
    }
    
    // Reset setup flag
    _requiresSetup = false;
    
    // Check if biometric is available
    final available = await isBiometricAvailable();
    if (!available) {
      if (!SecurityConfig.isProduction) {
        print('⚠️ Biometric not available - app unlocked');
      }
      _isLocked = false;
      return;
    }
    
    // Check if user has enabled biometric
    final enabled = await isBiometricEnabled();
    if (!enabled) {
      if (!SecurityConfig.isProduction) {
        print('ℹ️ Biometric disabled by user - app unlocked');
      }
      _isLocked = false;
      return;
    }
    
    // Biometric is enabled - check if we should lock on startup
    final lastLockTime = await getLastLockTime();
    if (lastLockTime != null) {
      final elapsed = DateTime.now().difference(lastLockTime);
      if (elapsed > getSessionTimeout()) {
        _isLocked = true;
      } else {
        // Session still valid
        _isLocked = false;
      }
    } else {
      // Biometric enabled but no last lock time - require auth on first protected launch
      _isLocked = true;
    }
    
    if (!SecurityConfig.isProduction) {
      print('✅ BiometricAuthService initialized (locked: $_isLocked)');
    }
  }
  
  // ============================================================================
  // SECURITY UTILITIES
  // ============================================================================
  
  /// Stop all biometric activity (cleanup)
  Future<void> dispose() async {
    await _localAuth.stopAuthentication();
  }
  
  /// Force re-authentication (invalidate session)
  Future<void> invalidateSession() async {
    await lockApp();
    print('🔐 Session invalidated - re-authentication required');
  }
  
  /// Check if we should enforce biometric based on config
  bool shouldEnforceBiometric() {
    return SecurityConfigExtensions.shouldEnforceBiometric();
  }
  
  /// Clear all biometric settings (used on fresh install to reset Keychain data)
  Future<void> clearBiometricSettings() async {
    await _secureStorage.delete(key: _keyBiometricEnabled);
    await _secureStorage.delete(key: _keyHasCompletedSetup);
    await _secureStorage.delete(key: _keyBiometricPromptShown);
    await _secureStorage.delete(key: _keyLastLockTime);
    await _secureStorage.delete(key: _keySessionTimeout);
    _isLocked = false;
    _lastActivityTime = null;
    print('🗑️ Biometric settings cleared');
  }
}
