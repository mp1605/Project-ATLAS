import 'dart:io';
import 'package:health/health.dart';
import 'health_data_adapter.dart';
import '../database/health_data_repository.dart';

/// Apple Watch / HealthKit adapter
/// 
/// Provides health data from Apple's HealthKit on iOS devices.
/// Uses the flutter health package for HealthKit integration.
class AppleHealthAdapter implements HealthDataAdapter {
  final Health _health = Health();
  
  /// Military readiness metrics - AUTOMATIC from Apple Watch only
  /// No manual entry, no nutrition, no profile data
  /// 28 metrics total - all high-value for readiness scoring
  static const List<HealthDataType> _metricTypes = <HealthDataType>[
    // ========== CARDIOVASCULAR CORE (8) ==========
    HealthDataType.HEART_RATE, // Baseline exertion, stress, fatigue
    HealthDataType.RESTING_HEART_RATE, // Illness & overtraining detection
    HealthDataType.WALKING_HEART_RATE, // Aerobic efficiency
    HealthDataType.HEART_RATE_VARIABILITY_SDNN, // Long-term recovery
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // Short-term readiness
    HealthDataType.BLOOD_OXYGEN, // Altitude readiness, respiratory fitness
    HealthDataType.RESPIRATORY_RATE, // Breathing rate, illness detection
    HealthDataType.PERIPHERAL_PERFUSION_INDEX, // Circulation quality
    
    // ========== ACTIVITY & ENERGY (7) ==========
    HealthDataType.STEPS, // Volume proxy
    HealthDataType.DISTANCE_WALKING_RUNNING, // Endurance capacity
    HealthDataType.DISTANCE_CYCLING, // Sport-specific (if applicable)
    HealthDataType.DISTANCE_SWIMMING, // Military-relevant aquatic
    HealthDataType.FLIGHTS_CLIMBED, // Load & elevation capacity
    HealthDataType.ACTIVE_ENERGY_BURNED, // Training load
    HealthDataType.EXERCISE_TIME, // Workout duration
    
    // ========== SLEEP (8) - MISSION-CRITICAL ==========
    HealthDataType.SLEEP_ASLEEP, // Primary recovery metric
    HealthDataType.SLEEP_DEEP, // Physical repair
    HealthDataType.SLEEP_REM, // Cognitive readiness
    HealthDataType.SLEEP_LIGHT, // Complete staging
    HealthDataType.SLEEP_AWAKE, // Fragmentation insight
    HealthDataType.SLEEP_AWAKE_IN_BED, // Sleep efficiency
    HealthDataType.SLEEP_IN_BED, // Opportunity vs quality
    HealthDataType.SLEEP_SESSION, // Sleep period metadata
    
    // ========== STRESS & RECOVERY (2) ==========
    HealthDataType.ELECTRODERMAL_ACTIVITY, // Sympathetic stress marker
    HealthDataType.MINDFULNESS, // Behavioral recovery indicator
    
    // ========== HEART EVENTS - SAFETY (3) ==========
    HealthDataType.HIGH_HEART_RATE_EVENT, // Tachycardia
    HealthDataType.LOW_HEART_RATE_EVENT, // Bradycardia
    HealthDataType.IRREGULAR_HEART_RATE_EVENT, // Atrial fibrillation alert
  ];
  
  /// Interval-based metrics (duration = dateTo - dateFrom)
  /// vs point-based metrics (value = numeric sample)
  static const Set<String> _intervalMetrics = {
    // All sleep metrics are intervals
    'SLEEP_ASLEEP',
    'SLEEP_DEEP',
    'SLEEP_REM',
    'SLEEP_LIGHT',
    'SLEEP_AWAKE',
    'SLEEP_AWAKE_IN_BED',
    'SLEEP_IN_BED',
    'SLEEP_SESSION',
    // Recovery intervals
    'MINDFULNESS',
    'EXERCISE_TIME', // Can be interval or aggregate
    'WORKOUT',
  };
  
  /// Check if a metric type represents an interval (duration) vs a point (numeric value)
  static bool isIntervalMetric(String metricType) {
    return _intervalMetrics.contains(metricType);
  }

  @override
  String get deviceType => 'APPLE_WATCH';

  @override
  Future<void> initialize() async {
    // No initialization needed for Apple Health
    print('✅ AppleHealthAdapter initialized');
  }

  @override
  List<String> get supportedMetrics {
    return _metricTypes.map((t) => t.name).toList();
  }

  @override
  Future<void> dispose() async {
    // No cleanup needed
  }

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    try {
      // Just check if we can access the health API
      await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: DateTime.now().subtract(const Duration(minutes: 1)),
        endTime: DateTime.now(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isIOS) return false;
    try {
      // Create READ permissions for all metric types
      final permissions = List.filled(_metricTypes.length, HealthDataAccess.READ);
      
      print('🔐 Requesting HealthKit permissions for ${_metricTypes.length} metric types...');
      final result = await _health.requestAuthorization(_metricTypes, permissions: permissions);
      
      print('📋 HealthKit authorization result: $result');
      if (result) {
        print('✅ Health permissions granted! App should now appear in Settings → Health');
      } else {
        print('❌ Health permissions denied or partially granted');
      }
      
      return result;
    } catch (e) {
      print('❌ Permission request failed: $e');
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    if (!Platform.isIOS) return false;
    
    try {
      // Create READ permissions for all metric types
      final permissions = List.filled(_metricTypes.length, HealthDataAccess.READ);
      
      final hasPerms = await _health.hasPermissions(_metricTypes, permissions: permissions);
      
      print('🔍 Health permissions check: ${hasPerms ?? false}');
      return hasPerms ?? false;
    } catch (e) {
      print('⚠️ Permission check failed: $e');
      return false;
    }
  }

  @override
  Future<List<HealthMetric>> getMetrics({required Duration window}) async {
    final end = DateTime.now();
    
    // DUAL TIME WINDOWS: 24 hours for sleep, normal window for real-time data
    final realtimeStart = end.subtract(window);
    final sleepStart = end.subtract(const Duration(hours: 24));
    
    print('📊 AppleHealthAdapter: DUAL TIME WINDOWS');
    print('   Real-time data: last ${window.inMinutes} min (${realtimeStart.toLocal()} to ${end.toLocal()})');
    print('   Daily metrics (sleep, RHR, HRV, etc.): last 24 hours (${sleepStart.toLocal()} to ${end.toLocal()})');

    final allMetrics = <HealthMetric>[];
    int successfulTypes = 0;
    int failedTypes = 0;

    // Metrics calculated ONCE PER DAY or accumulated over 24h need longer window
    final dailyCalculatedTypes = {
      // Sleep metrics (calculated overnight)
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_AWAKE_IN_BED,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_SESSION,
      
      // Cardiovascular metrics (calculated once daily)
      HealthDataType.RESTING_HEART_RATE,  // Morning calculation
      HealthDataType.WALKING_HEART_RATE,   // Daily average
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,  // Overnight
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // Overnight
      
      // Respiratory metrics (measured during sleep)
      HealthDataType.RESPIRATORY_RATE,
      
      // Blood oxygen (measured overnight)
      HealthDataType.BLOOD_OXYGEN,
      
      // Activity metrics (accumulated over 24h)
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.DISTANCE_CYCLING,
      HealthDataType.DISTANCE_SWIMMING,
      HealthDataType.FLIGHTS_CLIMBED,
      HealthDataType.EXERCISE_TIME,
    };

    // Query each type individually to avoid one failure blocking everything
    for (var type in _metricTypes) {
      try {
        // Use 24h window for daily metrics, regular window for real-time
        final isDailyMetric = dailyCalculatedTypes.contains(type);
        final queryStart = isDailyMetric ? sleepStart : realtimeStart;
        final windowLabel = isDailyMetric ? '(24h)' : '(${window.inMinutes}min)';
        
        final points = await _health.getHealthDataFromTypes(
          types: [type], // Query ONE type at a time
          startTime: queryStart,
          endTime: end,
        );

        if (points.isNotEmpty) {
          successfulTypes++;
          print('  ✅ ${type.name} $windowLabel: ${points.length} points');
          
          // Convert to HealthMetric format
          for (var point in points) {
            final metricTypeName = point.type.name;
            final isInterval = isIntervalMetric(metricTypeName);
            
            double value;
            
            if (isInterval) {
              // For interval metrics (sleep, mindfulness, workouts):
              // value = duration in minutes
              final duration = point.dateTo.difference(point.dateFrom).inMinutes;
              value = duration.toDouble().clamp(0.0, double.infinity); // No negative durations
              
              if (duration > 0) {
                print('    📏 ${metricTypeName}: ${duration}min (${point.dateFrom.toLocal()} → ${point.dateTo.toLocal()})');
              }
            } else {
              // For point metrics (HR, HRV, SpO2, etc.):
              // value = numeric sample
              if (point.value is NumericHealthValue) {
                value = (point.value as NumericHealthValue).numericValue.toDouble();
              } else if (point.value is num) {
                value = (point.value as num).toDouble();
              } else {
                try {
                  value = double.parse(point.value.toString());
                } catch (e) {
                  print('    ⚠️ Could not parse value: ${point.value}');
                  value = 0.0;
                }
              }

              // Normalization for specific types
              if (metricTypeName == 'BLOOD_OXYGEN') {
                // Blood oxygen is often 0.0 to 1.0 in HealthKit
                if (value > 0 && value <= 1.0) {
                  value = value * 100.0;
                }
              }
            }

            allMetrics.add(HealthMetric(
              type: metricTypeName,
              value: value,
              unit: _normalizeUnit(metricTypeName, point.unit.name, isInterval),
              timestamp: point.dateTo,  // Use end time as primary timestamp
              source: point.sourceName,
              metadata: {
                'platform': point.sourcePlatform.name,
                'date_from': point.dateFrom.toIso8601String(),
                'date_to': point.dateTo.toIso8601String(),
                'is_interval': isInterval,
              },
            ));
          }
        }
      } catch (e) {
        failedTypes++;
        // Silently skip unavailable metric types (like HRV on some devices)
        print('  ⏭️  ${type.name}: Not available (skipped)');
      }
    }

    print('📊 Summary: $successfulTypes types available, $failedTypes unavailable');
    print('📊 Total data points collected: ${allMetrics.length}');

    // Deduplicate based on type + timestamp
    final seen = <String>{};
    final deduplicated = allMetrics.where((metric) {
      final key = '${metric.type}_${metric.timestamp.millisecondsSinceEpoch}';
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      return true;
    }).toList();

    print('📊 After deduplication: ${deduplicated.length} metrics');
    
    if (deduplicated.isEmpty) {
      print('⚠️  No data retrieved. Possible causes:');
      print('   1. User denied permissions');
      print('   2. No data in time window');
      print('   3. Apple Watch not synced');
    }

    return deduplicated;
  }

  /// Normalize units to consistent format across the app
  String _normalizeUnit(String metricType, String rawUnit, bool isInterval) {
    // Interval metrics are always in minutes
    if (isInterval) return 'min';
    
    // Energy metrics
    if (metricType.contains('ENERGY')) return 'kcal';
    
    // Distance metrics
    if (metricType.contains('DISTANCE')) return 'm';
    
    // Heart rate metrics
    if (metricType.contains('HEART_RATE') && !metricType.contains('VARIABILITY')) {
      return 'bpm';
    }
    
    // HRV metrics
    if (metricType.contains('VARIABILITY')) return 'ms';
    
    // Temperature
    if (metricType == 'BODY_TEMPERATURE') return 'C';
    
    // Steps, flights
    if (metricType == 'STEPS' || metricType == 'FLIGHTS_CLIMBED') return 'count';
    
    // Default: keep raw unit
    return rawUnit;
}
}
