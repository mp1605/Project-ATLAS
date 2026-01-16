import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();

  HealthService() {
    // health 11.x uses Health() constructor directly.
    // No configure() method needed - initialization is automatic.
    print('✅ HealthService: Initialized with health package 11.x');
  }

  /// Comprehensive health metrics for Live Sync
  /// Expanded from 3 to 23+ metrics for comprehensive health tracking
  static const List<HealthDataType> liveSyncTypes = <HealthDataType>[
    // ===== VITAL SIGNS (7 metrics) =====
    HealthDataType.HEART_RATE,                    // Continuous heart rate
    HealthDataType.RESTING_HEART_RATE,            // Resting HR (calculated daily)
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,   // HRV (stress/recovery)
    HealthDataType.BLOOD_OXYGEN,                  // SpO2
    HealthDataType.RESPIRATORY_RATE,              // Breathing rate
    HealthDataType.BODY_TEMPERATURE,              // Wrist temperature
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,       // Blood pressure (if available)
    
    // ===== ACTIVITY & MOVEMENT (6 metrics) =====
    HealthDataType.STEPS,                         // Step count
    HealthDataType.DISTANCE_WALKING_RUNNING,      // Distance
    HealthDataType.FLIGHTS_CLIMBED,               // Stairs/elevation
    HealthDataType.ACTIVE_ENERGY_BURNED,          // Active calories
    HealthDataType.BASAL_ENERGY_BURNED,           // Resting calories
    HealthDataType.EXERCISE_TIME,                 // Exercise minutes
    
    // ===== SLEEP (5 metrics) =====
    HealthDataType.SLEEP_IN_BED,                  // Time in bed
    HealthDataType.SLEEP_ASLEEP,                  // Total sleep
    HealthDataType.SLEEP_AWAKE,                   // Awake time
    HealthDataType.SLEEP_DEEP,                    // Deep sleep
    HealthDataType.SLEEP_REM,                     // REM sleep
    
    // ===== FITNESS & ALERTS (5 metrics) =====
    HealthDataType.HIGH_HEART_RATE_EVENT,         // High HR alerts
    HealthDataType.LOW_HEART_RATE_EVENT,          // Low HR alerts
    HealthDataType.IRREGULAR_HEART_RATE_EVENT,    // Irregular rhythm
    HealthDataType.WORKOUT,                       // Workout sessions
    HealthDataType.WATER,                         // Water intake
  ];

  /// Permissions: All READ-only for safety
  static final List<HealthDataAccess> liveSyncPerms = List.filled(
    liveSyncTypes.length,
    HealthDataAccess.READ,
  );

  Future<bool> requestAuthorization() async {
    print('🔐 HealthService: Requesting authorization for ${liveSyncTypes.length} data types...');
    try {
      final bool authorized = await _health.requestAuthorization(
        liveSyncTypes,
        permissions: liveSyncPerms,
      );
      print('✅ HealthService: Authorization request completed. Result: $authorized');
      print('⚠️ Note: On iOS, this may return true even if user denied (privacy feature)');
      return authorized;
    } catch (e, stackTrace) {
      print('❌ HealthService: Authorization request failed: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<bool> hasPermissions() async {
    print('🔍 HealthService: Checking if permissions were previously requested...');
    try {
      final bool? hasPerms = await _health.hasPermissions(
        liveSyncTypes,
        permissions: liveSyncPerms,
      );
      final result = hasPerms ?? false;
      print('ℹ️ HealthService: hasPermissions() returned: $result');
      print('⚠️ Note: On iOS, this does NOT verify actual data access!');
      return result;
    } catch (e, stackTrace) {
      print('❌ HealthService: hasPermissions() failed: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Test permissions by actually trying to read data
  /// This is the ONLY reliable way to verify iOS Health access
  Future<bool> testPermissions({Duration window = const Duration(hours: 1)}) async {
    print('🧪 HealthService: Testing actual data access (reading last ${window.inHours}h)...');
    try {
      final data = await readRecent(window: window);
      final success = data.isNotEmpty;
      if (success) {
        print('✅ HealthService: Test PASSED - Retrieved ${data.length} data points');
      } else {
        print('⚠️ HealthService: Test INCONCLUSIVE - No data found (might be denied or no data available)');
      }
      return success;
    } catch (e) {
      print('❌ HealthService: Test FAILED - Cannot read data: $e');
      return false;
    }
  }

  /// Get detailed permission status for each individual data type
  Future<Map<HealthDataType, String>> getDetailedPermissionStatus({
    Duration window = const Duration(hours: 24),
  }) async {
    print('🔍 HealthService: Testing individual data type access...');
    final Map<HealthDataType, String> status = {};
    
    for (var dataType in liveSyncTypes) {
      try {
        final end = DateTime.now();
        final start = end.subtract(window);
        
        final points = await _health.getHealthDataFromTypes(
          types: [dataType],
          startTime: start,
          endTime: end,
        );
        
        if (points.isNotEmpty) {
          status[dataType] = 'OK (${points.length} points)';
          print('  ✅ $dataType: ${points.length} data points found');
        } else {
          status[dataType] = 'No data (denied or unavailable)';
          print('  ⚠️ $dataType: No data found');
        }
      } catch (e) {
        status[dataType] = 'Error: $e';
        print('  ❌ $dataType: Error - $e');
      }
    }
    
    return status;
  }

  Future<List<HealthDataPoint>> readRecent({
    Duration window = const Duration(minutes: 10),
  }) async {
    final end = DateTime.now();
    final start = end.subtract(window);
    
    print('📊 HealthService: Reading data from ${start.toLocal()} to ${end.toLocal()}...');
    print('   Window: ${window.inMinutes} minutes');
    
    try {
      final points = await _health.getHealthDataFromTypes(
        types: liveSyncTypes,
        startTime: start,
        endTime: end,
      );

      print('📥 HealthService: Retrieved ${points.length} raw data points');
      
      final deduplicated = _health.removeDuplicates(points);
      print('📊 HealthService: After deduplication: ${deduplicated.length} points');
      
      if (deduplicated.isNotEmpty) {
        // Show sample of data for debugging
        final sample = deduplicated.take(3).toList();
        for (var point in sample) {
          print('   📌 ${point.type}: ${point.value} (${point.dateFrom})');
        }
        if (deduplicated.length > 3) {
          print('   ... and ${deduplicated.length - 3} more');
        }
      } else {
        print('⚠️ HealthService: No data retrieved. Possible causes:');
        print('   1. User denied permissions (iOS hides this for privacy)');
        print('   2. No data available in the time window');
        print('   3. Apple Watch not synced');
        print('   4. Running on iOS Simulator (has limited health data)');
      }
      
      return deduplicated;
    } catch (e, stackTrace) {
      print('❌ HealthService: Error reading health data: $e');
      print('Stack trace: $stackTrace');
      print('⚠️ Common causes:');
      print('   1. Permissions were denied');
      print('   2. HealthKit not available (simulator or device issues)');
      print('   3. Invalid date range');
      print('   4. Health package compatibility issue');
      rethrow;
    }
  }
}
