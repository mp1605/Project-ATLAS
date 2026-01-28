import 'dart:io';
import 'dart:developer' as developer;
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
    developer.log('HealthConnectAdapter initialized (Phase 1: Core Metrics)', name: 'HealthConnect');
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
      developer.log('Health Connect is available', name: 'HealthConnect');
      return true;
    } catch (e) {
      developer.log('Health Connect not available', name: 'HealthConnect', error: e);
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Create READ permissions for core metric types only
      final permissions = List.filled(_coreMetrics.length, HealthDataAccess.READ);
      
      developer.log(
        'Requesting Health Connect permissions',
        name: 'HealthConnect',
        error: null,
      );
      
      final result = await _health.requestAuthorization(_coreMetrics, permissions: permissions);
      
      developer.log(
        'Health Connect authorization: ${result ? "granted" : "denied"}',
        name: 'HealthConnect',
      );
      
      return result;
    } catch (e) {
      developer.log(
        'Health Connect permission request failed',
        name: 'HealthConnect',
        error: e,
      );
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
      
      developer.log(
        'Permission check: ${hasPerms ?? false}',
        name: 'HealthConnect',
      );
      return hasPerms ?? false;
    } catch (e) {
      developer.log('Permission check failed', name: 'HealthConnect', error: e);
      return false;
    }
  }

  @override
  Future<List<HealthMetric>> getMetrics({required Duration window}) async {
    final end = DateTime.now();
    final start = end.subtract(window);
    
    developer.log(
      'Querying Health Connect (window: ${window.inMinutes}min)',
      name: 'HealthConnect',
    );

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
                  developer.log('Could not parse value', name: 'HealthConnect', error: e);
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
        }
      } catch (e) {
        failedTypes++;
        statusReport[type.name] = 'Error: $e';
        developer.log('Metric query failed: ${type.name}', name: 'HealthConnect', error: e);
      }
    }

    // Calculate data completeness for confidence annotation
    final completeness = ((successfulTypes / _coreMetrics.length) * 100).round();
    developer.log(
      'Sync complete: $successfulTypes/$_coreMetrics.length metrics, coverage: $completeness%',
      name: 'HealthConnect',
    );

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

    if (deduplicated.isEmpty) {
      developer.log(
        'No data retrieved from Health Connect',
        name: 'HealthConnect',
      );
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
