import 'dart:io';
import 'health_data_adapter.dart';
import 'apple_health_adapter.dart';
import '../models/wearable_type.dart';

/// Factory to create the appropriate health data adapter
/// based on user selection and platform availability
class HealthAdapterFactory {
  /// Create adapter for the specified wearable type
  /// 
  /// Validates platform compatibility and returns the appropriate adapter.
  /// Throws an exception if the wearable type is not available on this platform.
  static HealthDataAdapter createAdapter(WearableType type) {
    final platform = Platform.isIOS ? 'ios' : 'android';
    
    // Validate platform compatibility
    if (!type.isAvailableOn(platform)) {
      throw UnsupportedError(
        '${type.displayName} is not available on ${platform.toUpperCase()}. '
        'Platform requirement not met.'
      );
    }

    // Create appropriate adapter
    switch (type) {
      case WearableType.appleWatch:
        if (!Platform.isIOS) {
          throw UnsupportedError('Apple Watch requires iOS');
        }
        return AppleHealthAdapter();
      
      case WearableType.garmin:
        throw UnimplementedError(
          'Garmin adapter not yet implemented. '
          'Integration: Garmin Health API (OAuth 1.0a). '
          'Coming in Phase 4.'
        );
      
      case WearableType.samsung:
      case WearableType.pixelWatch:
        throw UnimplementedError(
          'Health Connect adapter not yet implemented. '
          'Integration: Android Health Connect API. '
          'Coming in Phase 5.'
        );
      
      case WearableType.fitbit:
        throw UnimplementedError(
          'Fitbit adapter not yet implemented. '
          'Integration: Fitbit Web API (OAuth 2.0). '
          'Coming in Phase 6.'
        );
      
      case WearableType.ouraRing:
        throw UnimplementedError(
          'Oura Ring adapter not yet implemented. '
          'Integration: Oura Cloud API v2 (OAuth 2.0). '
          'API: https://cloud.ouraring.com/v2/docs'
        );
      
      case WearableType.whoop:
        throw UnimplementedError(
          'Whoop adapter not yet implemented. '
          'Integration: Whoop API (OAuth 2.0). '
          'API: https://developer.whoop.com/'
        );
      
      case WearableType.polar:
        throw UnimplementedError(
          'Polar adapter not yet implemented. '
          'Integration: Polar AccessLink API (OAuth 2.0). '
          'API: https://www.polar.com/accesslink-api/'
        );
      
      case WearableType.amazfit:
        throw UnimplementedError(
          'Amazfit adapter not yet implemented. '
          'Integration: Zepp API or Health Connect (Android). '
          'Note: Zepp API has limited third-party access.'
        );
      
      case WearableType.casio:
        throw UnimplementedError(
          'Casio G-SHOCK adapter not yet implemented. '
          'Integration: Health Connect (Android) via G-SHOCK Move app. '
          'Note: Limited API availability.'
        );
      
      case WearableType.other:
        throw UnsupportedError('No adapter available for "Other" wearable type');
    }
  }

  /// Get list of wearables available on current platform
  static List<WearableType> getAvailableWearables() {
    final platform = Platform.isIOS ? 'ios' : 'android';
    return WearableType.values
        .where((type) => type.isAvailableOn(platform))
        .toList();
  }

  /// Check if a specific wearable type can be used on this device
  static bool isSupported(WearableType type) {
    final platform = Platform.isIOS ? 'ios' : 'android';
    return type.isAvailableOn(platform);
  }

  /// Get list of implemented adapters (currently available)
  static List<WearableType> getImplementedAdapters() {
    return [
      WearableType.appleWatch, // Currently the only one implemented
    ];
  }

  /// Check if adapter is implemented
  static bool isImplemented(WearableType type) {
    return type == WearableType.appleWatch;
  }
}
