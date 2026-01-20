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
  /// Core readiness metrics - Scientifically justified Tier 1 & 2 only
  /// Total: 35 metrics (reduced from 85)
  static const List<HealthDataType> _metricTypes = <HealthDataType>[
    // ========== TIER 1: CARDIOVASCULAR CORE (11) ==========
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BODY_TEMPERATURE,
    
    // Heart Events - Safety
    HealthDataType.HIGH_HEART_RATE_EVENT,
    HealthDataType.LOW_HEART_RATE_EVENT,
    HealthDataType.IRREGULAR_HEART_RATE_EVENT,
    
    // Blood Pressure
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    
    // ========== TIER 1: SLEEP (8) ==========
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_SESSION,
    
    // ========== TIER 1: ACTIVITY & LOAD (9) ==========
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.DISTANCE_CYCLING,
    HealthDataType.DISTANCE_SWIMMING,
    HealthDataType.FLIGHTS_CLIMBED,
    
    // ========== TIER 2: BODY & STRESS (7) ==========
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.LEAN_BODY_MASS,
    HealthDataType.ELECTRODERMAL_ACTIVITY,
    HealthDataType.MINDFULNESS,
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
    
    // Activity intervals
    'MINDFULNESS',
    'WORKOUT',
    'EXERCISE_TIME',
    'ELECTRODERMAL_ACTIVITY',
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
    
    // SMART WINDOW LOGIC: Ensure we bridge the requested window for ALL metrics
    final realtimeStart = end.subtract(window);
    
    // Daily metrics (sleep, RHR, etc.) should use the requested window OR 24h (whichever is larger)
    final dailyWindow = window > const Duration(hours: 24) ? window : const Duration(hours: 24);
    final dailyStart = end.subtract(dailyWindow);
    
    print('📊 AppleHealthAdapter: DUAL TIME WINDOWS');
    print('   Real-time data: last ${window.inMinutes} min (${realtimeStart.toLocal()} to ${end.toLocal()})');
    print('   Daily metrics: last ${dailyWindow.inHours} hours (${dailyStart.toLocal()} to ${end.toLocal()})');

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
      HealthDataType.SLEEP_OUT_OF_BED, // NEW in v13.2.1
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_UNKNOWN, // NEW in v13.2.1
      
      // Cardiovascular metrics (calculated once daily)
      HealthDataType.RESTING_HEART_RATE,  // Morning calculation
      HealthDataType.WALKING_HEART_RATE,   // Daily average
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,  // Overnight
      HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // Overnight
      HealthDataType.ATRIAL_FIBRILLATION_BURDEN, // NEW in v13.2.1 - daily calculation
      
      // Respiratory metrics (measured during sleep)
      HealthDataType.RESPIRATORY_RATE,
      HealthDataType.FORCED_EXPIRATORY_VOLUME, // NEW in v13.2.1 - periodic measurement
      
      // Blood oxygen (measured overnight)
      HealthDataType.BLOOD_OXYGEN,
      
      // Activity metrics (accumulated over 24h)
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.DISTANCE_CYCLING,
      HealthDataType.DISTANCE_SWIMMING,
      HealthDataType.FLIGHTS_CLIMBED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.TOTAL_CALORIES_BURNED, // NEW in v13.2.1 - daily total
      HealthDataType.APPLE_STAND_HOUR, // NEW in v13.2.1 - hourly goals accumulated
      
      // Metrics that often have fewer samples or are calculated/accumulated
      HealthDataType.BODY_TEMPERATURE,
      HealthDataType.WORKOUT,
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.AUDIOGRAM, // NEW in v13.2.1 - periodic tests
    };

    // Query each type individually to avoid one failure blocking everything
    for (var type in _metricTypes) {
      try {
        // Use 24h window for daily metrics, regular window for real-time
        final isDailyMetric = dailyCalculatedTypes.contains(type);
        final queryStart = isDailyMetric ? dailyStart : realtimeStart;
        final windowLabel = isDailyMetric ? '(${dailyWindow.inHours}h)' : '(${window.inMinutes}min)';
        
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
            final metricTypeName = _mapToLegacyType(point.type.name); // Normalize Keys
            final isInterval = isIntervalMetric(point.type.name); // Use original for interval check
            
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
    
    // Energy & calories
    if (metricType.contains('ENERGY') || metricType.contains('CALORIES')) return 'kcal';
    
    // Distance & speed
    if (metricType.contains('DISTANCE')) return 'm';
    if (metricType.contains('SPEED')) return 'm/s';
    
    // Heart rate metrics
    if (metricType.contains('HEART_RATE') && !metricType.contains('VARIABILITY')) return 'bpm';
    if (metricType.contains('VARIABILITY')) return 'ms';
    if (metricType.contains('FIBRILLATION')) return '%';
    
    // Blood pressure
    if (metricType.contains('BLOOD_PRESSURE')) return 'mmHg';
    
    // Temperature
    if (metricType.contains('TEMPERATURE')) return '°C';
    
    // Counts
    if (metricType == 'STEPS' || metricType == 'FLIGHTS_CLIMBED') return 'count';
    if (metricType == 'UV_INDEX') return 'index';
    if (metricType == 'APPLE_STAND_HOUR') return 'hours';
    
    // Body measurements
    if (metricType.contains('WEIGHT') || metricType.contains('MASS')) return 'kg';
    if (metricType == 'HEIGHT' || metricType.contains('CIRCUMFERENCE')) return 'cm';
    if (metricType == 'BODY_MASS_INDEX') return 'index';
    if (metricType.contains('FAT_PERCENTAGE') || metricType == 'BODY_FAT_PERCENTAGE') return '%';
    
    // Blood glucose & insulin
    if (metricType == 'BLOOD_GLUCOSE') return 'mg/dL';
    if (metricType == 'INSULIN_DELIVERY') return 'IU';
    
    // Respiratory
    if (metricType == 'FORCED_EXPIRATORY_VOLUME') return 'L';
    if (metricType == 'RESPIRATORY_RATE') return '/min';
    if (metricType == 'PERIPHERAL_PERFUSION_INDEX') return '%';
    
    // Water & liquids
    if (metricType == 'WATER') return 'L';
    if (metricType == 'UNDERWATER_DEPTH') return 'm';
    
    // Hearing
    if (metricType == 'AUDIOGRAM') return 'dBHL';
    
    // ECG
    if (metricType == 'ELECTROCARDIOGRAM') return 'V';
    if (metricType == 'ELECTRODERMAL_ACTIVITY') return 'μS';
    
    // Nutrition metrics
    if (metricType.contains('DIETARY')) {
      if (metricType.contains('ENERGY')) return 'kcal';
      // Most vitamins/minerals in grams, but caffeine & some minerals in mg
      if (metricType.contains('VITAMIN') || metricType.contains('MINERAL')) return 'g';
      return 'g';
    }
    
    // Categorical
    if (metricType == 'MENSTRUATION_FLOW') return 'level';
    
    // Default: keep raw unit
    return rawUnit;
  }

  /// Map modern HealthKit types to legacy keys expected by calculators
  String _mapToLegacyType(String type) {
    switch (type) {
      case 'HEART_RATE_VARIABILITY_RMSSD':
        return 'HRV_RMSSD';
      case 'HEART_RATE_VARIABILITY_SDNN':
        return 'HRV_SDNN';
      default:
        return type;
    }
  }
}
