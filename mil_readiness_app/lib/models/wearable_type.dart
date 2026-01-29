/// Wearable device types supported by the app
enum WearableType {
  appleWatch,
  garmin,
  samsung,
  fitbit,
  pixelWatch,
  ouraRing,
  whoop,
  casio,
  amazfit,
  polar,
  other;

  /// Human-readable name for the wearable
  String get displayName {
    switch (this) {
      case WearableType.appleWatch:
        return 'Apple Watch';
      case WearableType.garmin:
        return 'Garmin';
      case WearableType.samsung:
        return 'Samsung Galaxy Watch';
      case WearableType.fitbit:
        return 'Fitbit';
      case WearableType.pixelWatch:
        return 'Google Pixel Watch';
      case WearableType.ouraRing:
        return 'Oura Ring';
      case WearableType.whoop:
        return 'Whoop';
      case WearableType.casio:
        return 'Casio G-SHOCK';
      case WearableType.amazfit:
        return 'Amazfit';
      case WearableType.polar:
        return 'Polar';
      case WearableType.other:
        return 'Other';
    }
  }

  /// Platform requirements
  bool isAvailableOn(String platform) {
    switch (this) {
      case WearableType.appleWatch:
        return platform == 'ios';
      case WearableType.garmin:
      case WearableType.fitbit:
      case WearableType.ouraRing:
      case WearableType.whoop:
      case WearableType.polar:
        return true; // Available on both via cloud API
      case WearableType.samsung:
      case WearableType.pixelWatch:
      case WearableType.amazfit:
        return platform == 'android';
      case WearableType.casio:
        return platform == 'android'; // G-SHOCK Move app is Android only
      case WearableType.other:
        return true;
    }
  }

  /// Icon name for the wearable
  String get iconName {
    switch (this) {
      case WearableType.appleWatch:
        return 'watch';
      case WearableType.garmin:
        return 'fitness_center';
      case WearableType.samsung:
      case WearableType.pixelWatch:
        return 'watch_later';
      case WearableType.fitbit:
        return 'favorite';
      case WearableType.ouraRing:
        return 'radio_button_unchecked';
      case WearableType.whoop:
        return 'trending_up';
      case WearableType.casio:
        return 'timer';
      case WearableType.amazfit:
        return 'sports_score';
      case WearableType.polar:
        return 'explore';
      case WearableType.other:
        return 'devices_other';
    }
  }

  /// Description for the wearable
  String get description {
    switch (this) {
      case WearableType.appleWatch:
        return 'Apple Watch via HealthKit';
      case WearableType.garmin:
        return 'Garmin watches via Garmin Health API';
      case WearableType.samsung:
        return 'Samsung Galaxy Watch via Health Connect';
      case WearableType.fitbit:
        return 'Fitbit devices via Fitbit Web API';
      case WearableType.pixelWatch:
        return 'Google Pixel Watch via Health Connect';
      case WearableType.ouraRing:
        return 'Oura Ring via Oura Cloud API';
      case WearableType.whoop:
        return 'Whoop via Whoop API';
      case WearableType.casio:
        return 'Casio G-SHOCK via G-SHOCK Move';
      case WearableType.amazfit:
        return 'Amazfit via Zepp/Health Connect';
      case WearableType.polar:
        return 'Polar devices via Polar AccessLink API';
      case WearableType.other:
        return 'Other devices';
    }
  }

  /// Integration method required
  String get integrationMethod {
    switch (this) {
      case WearableType.appleWatch:
        return 'HealthKit (built-in)';
      case WearableType.garmin:
        return 'Garmin Health API (OAuth)';
      case WearableType.samsung:
      case WearableType.pixelWatch:
        return 'Health Connect (Android)';
      case WearableType.fitbit:
        return 'Fitbit Web API (OAuth)';
      case WearableType.ouraRing:
        return 'Oura Cloud API (OAuth 2.0)';
      case WearableType.whoop:
        return 'Whoop API (OAuth 2.0)';
      case WearableType.casio:
        return 'Health Connect (Android)';
      case WearableType.amazfit:
        return 'Zepp API / Health Connect';
      case WearableType.polar:
        return 'Polar AccessLink API (OAuth 2.0)';
      case WearableType.other:
        return 'N/A';
    }
  }

  /// Check if device requires specific hardware to function
  /// Returns null if no special requirement, otherwise returns requirement message
  String? get hardwareRequirement {
    switch (this) {
      case WearableType.samsung:
        return 'Requires Samsung Galaxy phone for full compatibility';
      default:
        return null;
    }
  }

  /// Check if device is temporarily disabled due to hardware constraints
  bool get isTemporarilyDisabled {
    return this == WearableType.samsung; // Disabled until Samsung Galaxy phone available
  }
}

