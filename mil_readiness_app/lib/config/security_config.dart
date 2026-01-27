import 'dart:io';

/// Centralized security configuration for the military readiness application
/// 
/// This class provides environment-based security settings without hardcoding
/// sensitive values. All security parameters are configurable.
/// 
/// Security Features:
/// - Certificate pinning configuration
/// - Biometric authentication settings
/// - Encryption key rotation parameters
/// - Feature flags for emergency disable
class SecurityConfig {
  // ============================================================================
  // ENVIRONMENT CONFIGURATION
  // ============================================================================
  
  /// Current environment (set at build time or runtime)
  static Environment currentEnvironment = Environment.production;
  
  /// Get environment-specific configuration
  static SecurityEnvironment get environment {
    switch (currentEnvironment) {
      case Environment.development:
        return _devConfig;
      case Environment.staging:
        return _stagingConfig;
      case Environment.production:
        return _prodConfig;
    }
  }
  
  // ============================================================================
  // CERTIFICATE PINNING CONFIGURATION
  // ============================================================================
  
  /// Whether certificate pinning is enabled (kill-switch)
  /// Set to false to disable pinning in case of emergency
  static bool enableCertificatePinning = true;
  
  /// Production certificate pins (SHA-256 hashes of public keys)
  /// 
  /// To get the certificate pin for your server:
  /// 1. openssl s_client -connect atlas-backend-dx6g.onrender.com:443 -servername atlas-backend-dx6g.onrender.com < /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
  /// 2. Format as: sha256/BASE64_HASH
  /// 
  /// IMPORTANT: Always include at least 2 pins (current + backup) for rotation
  static const List<String> productionCertificatePins = [
    // Primary pin - replace with your actual certificate pin
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    // Backup pin - for certificate rotation
    'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
  ];
  
  /// Staging certificate pins
  static const List<String> stagingCertificatePins = [
    'sha256/STAGING_PIN_1',
    'sha256/STAGING_PIN_2',
  ];
  
  /// Development certificate pins (usually self-signed, pinning disabled)
  static const List<String> developmentCertificatePins = [];
  
  /// Whether to allow connections if pinning fails (ONLY for development)
  static bool get allowPinningBypass {
    return currentEnvironment == Environment.development;
  }
  
  // ============================================================================
  // BIOMETRIC AUTHENTICATION CONFIGURATION
  // ============================================================================
  
  /// Whether biometric authentication is required
  /// Set to false to disable biometric lock entirely
  static bool biometricRequired = true;
  
  /// Enterprise strict biometric mode
  /// 
  /// - true: Only biometric allowed (Face ID/Touch ID), NO passcode fallback
  ///   Use for high-security military/enterprise deployments
  /// - false: Allow OS passcode fallback if biometric fails
  ///   More user-friendly for general deployments
  static bool enterpriseStrictBiometric = true;
  
  /// Whether biometric setup is mandatory on first launch
  /// 
  /// - true: User CANNOT skip biometric setup, must configure before using app
  /// - false: User can choose to skip/disable biometric on first launch
  static bool biometricSetupRequired = false;
  
  /// Session timeout duration (app locks after this time in background)
  /// Options: immediate, 5min, 15min, 30min
  static Duration sessionTimeout = const Duration(minutes: 15);
  
  /// Lock app immediately when backgrounded (ignores timeout)
  static bool lockOnBackground = false;
  
  /// Allow biometric fallback to PIN/passcode (DEPRECATED - use enterpriseStrictBiometric)
  @Deprecated('Use enterpriseStrictBiometric instead')
  static bool get allowBiometricFallback => !enterpriseStrictBiometric;
  
  /// Biometric prompt message
  static String get biometricPromptMessage {
    if (Platform.isIOS) {
      return 'Authenticate to access your readiness data';
    } else {
      return 'Use your fingerprint to unlock';
    }
  }
  
  // ============================================================================
  // ENCRYPTION KEY MANAGEMENT
  // ============================================================================
  
  /// Automatic key rotation interval (default: 90 days)
  static const Duration keyRotationInterval = Duration(days: 90);
  
  /// Whether to automatically rotate encryption keys
  static bool autoRotateKeys = true;
  
  /// Grace period after rotation deadline before forcing rotation
  static const Duration keyRotationGracePeriod = Duration(days: 7);
  
  /// Maximum number of old keys to retain (for data recovery)
  static const int maxOldKeysRetained = 2;
  
  /// Warning threshold (warn user N days before rotation)
  static const Duration keyRotationWarningThreshold = Duration(days: 7);
  
  // ============================================================================
  // FEATURE FLAGS (Remote configurable in production)
  // ============================================================================
  
  /// Feature flags for emergency disable or gradual rollout
  static final FeatureFlags features = FeatureFlags();
  
  // ============================================================================
  // SECURITY AUDIT LOGGING
  // ============================================================================
  
  /// Enable security event logging (authentication, pinning failures, etc.)
  static bool enableSecurityLogging = true;
  
  /// Maximum security log entries to retain
  static const int maxSecurityLogEntries = 1000;
  
  // ============================================================================
  // ENVIRONMENT HELPERS
  // ============================================================================
  
  /// Check if running in production environment
  /// Used to suppress debug logging in release builds
  static bool get isProduction => currentEnvironment == Environment.production;
}

// ==============================================================================
// ENVIRONMENT DEFINITIONS
// ==============================================================================

enum Environment {
  development,
  staging,
  production,
}

class SecurityEnvironment {
  final String apiBaseUrl;
  final List<String> certificatePins;
  final bool strictPinning;
  
  const SecurityEnvironment({
    required this.apiBaseUrl,
    required this.certificatePins,
    required this.strictPinning,
  });
}

// Development environment (localhost, self-signed certs)
const _devConfig = SecurityEnvironment(
  apiBaseUrl: 'http://localhost:3000',
  certificatePins: [],
  strictPinning: false,
);

// Staging environment
const _stagingConfig = SecurityEnvironment(
  apiBaseUrl: 'https://staging-atlas-backend.onrender.com',
  certificatePins: SecurityConfig.stagingCertificatePins,
  strictPinning: true,
);

// Production environment
const _prodConfig = SecurityEnvironment(
  apiBaseUrl: 'https://atlas-backend-dx6g.onrender.com',
  certificatePins: SecurityConfig.productionCertificatePins,
  strictPinning: true,
);

// ==============================================================================
// FEATURE FLAGS
// ==============================================================================

class FeatureFlags {
  // Certificate pinning
  bool certificatePinning = true;
  
  // Biometric authentication
  bool biometricAuth = true;
  
  // Automatic key rotation
  bool automaticKeyRotation = true;
  
  // Security logging
  bool securityAuditLog = true;
  
  /// Load feature flags from remote config (future implementation)
  Future<void> refresh() async {
    // TODO: Implement remote config fetching (Firebase Remote Config, etc.)
    // For now, flags are hardcoded
    print('🚩 Feature flags loaded (local defaults)');
  }
  
  /// Reset to defaults
  void reset() {
    certificatePinning = true;
    biometricAuth = true;
    automaticKeyRotation = true;
    securityAuditLog = true;
  }
}

// ==============================================================================
// SECURITY UTILITIES
// ==============================================================================

/// Helper methods for security configuration
extension SecurityConfigExtensions on SecurityConfig {
  /// Get current certificate pins for active environment
  static List<String> getCurrentCertificatePins() {
    return SecurityConfig.environment.certificatePins;
  }
  
  /// Check if certificate pinning should be enforced
  static bool shouldEnforcePinning() {
    return SecurityConfig.enableCertificatePinning && 
           SecurityConfig.features.certificatePinning &&
           SecurityConfig.environment.strictPinning;
  }
  
  /// Check if biometric authentication should be enforced
  static bool shouldEnforceBiometric() {
    return SecurityConfig.biometricRequired && 
           SecurityConfig.features.biometricAuth;
  }
  
  /// Check if key rotation should happen automatically
  static bool shouldAutoRotateKeys() {
    return SecurityConfig.autoRotateKeys && 
           SecurityConfig.features.automaticKeyRotation;
  }
}
