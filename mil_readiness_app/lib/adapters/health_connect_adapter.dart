import 'dart:io';
import 'package:health/health.dart';
import 'health_data_adapter.dart';
import '../database/health_data_repository.dart';

/// Health Connect adapter for Android devices
/// 
/// Provides health data from Android's Health Connect on Android 9+ devices.
/// Supports Samsung Gear S3, Pixel Watch, and other wearables that sync to Health Connect.
/// Uses the flutter health package for Health Connect integration.
/// 
/// Phase 1: Core metrics only (steps, heart rate, sleep sessions)
class HealthConnectAdapter implements HealthDataAdapter {
  final Health _health = Health();
  
  /// Phase 1: Core metrics for baseline readiness
  /// Strictly limited to avoid permission fatigue
  static const List<HealthDataType> _coreMetrics = <HealthDataType>[
    // Activity
    HealthDataType.STEPS,
    
    // Cardiovascular
    HealthDataType.HEART_RATE,
    
    // Sleep
    HealthDataType.SLEEP_SESSION,  // Total sleep duration
  ];
  
  /// Metrics that represent intervals/durations rather than point values
  static const Set<String> _intervalMetrics = {
    'SLEEP_SESSION',
  };
  
  /// Check if a metric type represents an interval (duration) vs a point (numeric value)
  static bool isIntervalMetric(String metricType) {
    return _intervalMetrics.contains(metricType);
  }

  @override
  String get deviceType => 'HEALTH_CONNECT';

  @override
  Future<void> initialize() async {
    // No initialization needed for Health Connect
    print('✅ HealthConnectAdapter initialized (Phase 1: Core Metrics)');
  }

  @override
  List<String> get supportedMetrics {
    return _coreMetrics.map((t) => t.name).toList();
  }

  @override
  Future<void> dispose() async {
    // No cleanup needed
  }

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Test if we can access Health Connect by trying to query steps
      await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: DateTime.now().subtract(const Duration(minutes: 1)),
        endTime: DateTime.now(),
      );
      print('✅ Health Connect is available');
      return true;
    } catch (e) {
      print('⚠️ Health Connect not available: $e');
      print('   Possible causes:');
      print('   1. Health Connect app not installed (requires Android 14+)');
      print('   2. Samsung Health not synced to Health Connect');
      print('   3. Device does not support Health Connect');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Create READ permissions for core metric types only
      final permissions = List.filled(_coreMetrics.length, HealthDataAccess.READ);
      
      print('🔐 Requesting Health Connect permissions for ${_coreMetrics.length} core metrics...');
      print('   📊 Metrics: Steps, Heart Rate, Sleep Sessions');
      
      final result = await _health.requestAuthorization(_coreMetrics, permissions: permissions);
      
      print('📋 Health Connect authorization result: $result');
      if (result) {
        print('✅ Health Connect permissions granted!');
        print('   ℹ️ Data will sync from: Samsung Health, Google Fit, or other provider apps');
      } else {
        print('❌ Health Connect permissions denied or partially granted');
        print('   💡 User can grant permissions later in Health Connect app');
      }
      
      return result;
    } catch (e) {
      print('❌ Health Connect permission request failed: $e');
      print('   Common causes:');
      print('   1. Health Connect app not installed');
      print('   2. Incompatible Android version');
      print('   3. Samsung Health not configured');
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Create READ permissions for core metric types
      final permissions = List.filled(_coreMetrics.length, HealthDataAccess.READ);
      
      final hasPerms = await _health.hasPermissions(_coreMetrics, permissions: permissions);
      
      print('🔍 Health Connect permissions check: ${hasPerms ?? false}');
      return hasPerms ?? false;
    } catch (e) {
      print('⚠️ Health Connect permission check failed: $e');
      return false;
    }
  }

  @override
  Future<List<HealthMetric>> getMetrics({required Duration window}) async {
    final end = DateTime.now();
    final start = end.subtract(window);
    
    print('📊 HealthConnectAdapter: Querying Health Connect data');
    print('   Time window: ${window.inMinutes} min (${start.toLocal()} to ${end.toLocal()})');
    print('   Core metrics: Steps, Heart Rate, Sleep');

    final allMetrics = <HealthMetric>[];
    int successfulTypes = 0;
    int failedTypes = 0;
    Map<String, String> statusReport = {};

    // Query each type individually for better error handling and diagnostics
    for (var type in _coreMetrics) {
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [type],
          startTime: start,
          endTime: end,
        );

        if (points.isNotEmpty) {
          successfulTypes++;
          statusReport[type.name] = 'OK - ${points.length} points';
          print('  ✅ ${type.name}: ${points.length} points');
          
          // Convert to HealthMetric format
          for (var point in points) {
            final metricTypeName = point.type.name;
            final isInterval = isIntervalMetric(metricTypeName);
            
            double value;
            
            if (isInterval) {
              // For interval metrics (sleep sessions):
              // value = duration in minutes
              final duration = point.dateTo.difference(point.dateFrom).inMinutes;
              value = duration.toDouble().clamp(0.0, double.infinity);
              
              if (duration > 0) {
                print('    📏 ${metricTypeName}: ${duration}min (${point.dateFrom.toLocal()} → ${point.dateTo.toLocal()})');
              }
            } else {
              // For point metrics (steps, heart rate):
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
            }

            allMetrics.add(HealthMetric(
              type: metricTypeName,
              value: value,
              unit: _normalizeUnit(metricTypeName, point.unit.name, isInterval),
              timestamp: point.dateTo,  // Use end time as primary timestamp
              source: point.sourceName,
              metadata: {
                'platform': 'android_health_connect',
                'source_app': point.sourceName,  // e.g., "Samsung Health", "Google Fit"
                'date_from': point.dateFrom.toIso8601String(),
                'date_to': point.dateTo.toIso8601String(),
                'is_interval': isInterval,
              },
            ));
          }
        } else {
          failedTypes++;
          statusReport[type.name] = 'No data';
          print('  ⚠️ ${type.name}: No data in time window');
          print('     Possible causes:');
          print('     - Samsung Health not synced to Health Connect');
          print('     - No data recorded by wearable device');
          print('     - Sync delay (Health Connect can take 5-15 minutes)');
        }
      } catch (e) {
        failedTypes++;
        statusReport[type.name] = 'Error: $e';
        print('  ❌ ${type.name}: Error - $e');
        print('     Possible causes:');
        print('     - Permission denied for this specific metric');
        print('     - Health Connect not properly configured');
        print('     - Provider app (Samsung Health) not sharing data');
      }
    }

    print('📊 Health Connect Query Summary:');
    print('   ✅ Successful: $successfulTypes metrics');
    print('   ⚠️ No data: $failedTypes metrics');
    print('   📈 Total data points: ${allMetrics.length}');
    
    // Calculate data completeness for confidence scoring
    final completeness = ((successfulTypes / _coreMetrics.length) * 100).round();
    print('   📊 Data completeness: $completeness%');

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
      print('⚠️ No data retrieved from Health Connect');
      print('   🔍 Troubleshooting steps:');
      print('   1. Open Samsung Health app and ensure data is syncing');
      print('   2. Open Health Connect app and verify Samsung Health is connected');
      print('   3. Wait 5-15 minutes for Health Connect to sync');
      print('   4. Ensure Samsung Gear S3 is paired and syncing to Samsung Health');
      print('   5. Check that permissions were granted in Health Connect');
      print('');
      print('   📊 Status Report:');
      statusReport.forEach((metric, status) {
        print('      ${metric}: $status');
      });
    } else {
      print('✅ Health Connect data successfully retrieved');
      print('   Data completeness: $completeness% ($successfulTypes/${_coreMetrics.length} metrics)');
    }

    return deduplicated;
  }

  /// Normalize units to consistent format across the app
  String _normalizeUnit(String metricType, String rawUnit, bool isInterval) {
    // Interval metrics are always in minutes
    if (isInterval) return 'min';
    
    // Heart rate metrics
    if (metricType.contains('HEART_RATE')) return 'bpm';
    
    // Steps
    if (metricType == 'STEPS') return 'count';
    
    // Default: keep raw unit
    return rawUnit;
  }
}
