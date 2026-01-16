import '../database/health_data_repository.dart';

/// Abstract interface for health data adapters
/// 
/// Each wearable type (Apple Watch, Garmin, Samsung, etc.) implements this
/// interface to provide a unified way to access health data regardless of
/// the underlying platform or API.
abstract class HealthDataAdapter {
  /// Request permissions from the user to access health data
  /// 
  /// Returns true if all required permissions are granted, false otherwise.
  /// May show platform-specific permission dialogs.
  Future<bool> requestPermissions();

  /// Check if required permissions are currently granted
  /// 
  /// Note: On iOS, this may return false even when permissions are granted
  /// due to Apple's privacy features. Use with caution.
  Future<bool> hasPermissions();

  /// Retrieve health metrics within a specific time window
  /// 
  /// [window] - Duration to look back from now (e.g., Duration(hours: 24))
  /// 
  /// Returns a list of HealthMetric objects that can be stored in the
  /// encrypted database.
  Future<List<HealthMetric>> getMetrics({required Duration window});

  /// Check if this adapter is available on the current platform
  /// 
  /// For example, Apple Watch adapter is only available on iOS.
  /// 
  /// Returns true if the adapter can function on this device.
  Future<bool> isAvailable();

  /// Get the wearable type this adapter supports
  String get deviceType;

  /// Get list of metric types this adapter can collect
  /// 
  /// Returns list of metric type names (e.g., ['HEART_RATE', 'STEPS'])
  List<String> get supportedMetrics;

  /// Initialize the adapter
  /// 
  /// Called once during app startup. Can be used for any one-time setup.
  Future<void> initialize();

  /// Clean up resources
  /// 
  /// Called when the adapter is no longer needed.
  Future<void> dispose();
}
