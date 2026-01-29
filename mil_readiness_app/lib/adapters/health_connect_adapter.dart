import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
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
  
  /// Controlled logging - disabled in release builds
  /// Never logs: timestamps, sources, raw values, or per-point details
  void _log(String message, {Object? error}) {
    if (!kReleaseMode) {
      developer.log(message, name: 'HealthConnect', error: error);
    }
  }
  
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
    _log('HealthConnectAdapter initialized');
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
    // Phase 1: Conservative check - availability handled via permission flow + error messages
    // Attempting data reads here causes false negatives (permissions, no data, provider not connected)
    return Platform.isAndroid;
  }

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Create READ permissions for core metric types only
      final permissions = List.filled(_coreMetrics.length, HealthDataAccess.READ);
      
      _log('Requesting permissions');
      
      final result = await _health.requestAuthorization(_coreMetrics, permissions: permissions);
      
      _log('Authorization: ${result ? "granted" : "denied"}');
      
      return result;
    } catch (e) {
      _log('Permission request failed', error: e);
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
      
      _log('Permission check: ${hasPerms ?? false}');
      return hasPerms ?? false;
    } catch (e) {
      _log('Permission check failed', error: e);
      return false;
    }
  }

  @override
  Future<List<HealthMetric>> getMetrics({required Duration window}) async {
    final end = DateTime.now();
    final start = end.subtract(window);
    
    _log('Querying data (window: ${window.inMinutes}min)');

    final allMetrics = <HealthMetric>[];
    int successfulTypes = 0;
    int failedTypes = 0;

    // Query each type individually for better error handling
    for (var type in _coreMetrics) {
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [type],
          startTime: start,
          endTime: end,
        );

        if (points.isNotEmpty) {
          successfulTypes++;
          
          // Special handling: Aggregate sleep sessions into total duration
          if (type == HealthDataType.SLEEP_SESSION) {
            double totalSleepMinutes = 0;
            for (var point in points) {
              final duration = point.dateTo.difference(point.dateFrom).inMinutes;
              totalSleepMinutes += duration.toDouble().clamp(0.0, double.infinity);
            }
            
            // Emit one aggregated sleep metric for the window
            allMetrics.add(HealthMetric(
              type: 'SLEEP_SESSION',
              value: totalSleepMinutes,
              unit: 'min',
              timestamp: end, // Use query end time
              source: 'Health Connect',
              metadata: {
                'platform': 'android',
                'is_interval': true,
              },
            ));
          } else {
            // For non-aggregated metrics (steps, heart rate): convert each point
            for (var point in points) {
              final metricTypeName = point.type.name;
              double value;
              
              // Point metrics (steps, heart rate): value = numeric sample
              if (point.value is NumericHealthValue) {
                value = (point.value as NumericHealthValue).numericValue.toDouble();
              } else if (point.value is num) {
                value = (point.value as num).toDouble();
              } else {
                try {
                  value = double.parse(point.value.toString());
                } catch (e) {
                  _log('Parse error', error: e);
                  value = 0.0;
                }
              }

              allMetrics.add(HealthMetric(
                type: metricTypeName,
                value: value,
                unit: _normalizeUnit(metricTypeName, point.unit.name, false),
                timestamp: point.dateTo,
                source: 'Health Connect',
                metadata: {
                  'platform': 'android',
                  'is_interval': false,
                  'date_from': point.dateFrom.toIso8601String(),
                  'date_to': point.dateTo.toIso8601String(),
                },
              ));
            }
          }
        } else {
          failedTypes++;
        }
      } catch (e) {
        failedTypes++;
        _log('Query failed', error: e);
      }
    }

    // Calculate data completeness for confidence annotation
    final completeness = ((successfulTypes / _coreMetrics.length) * 100).round();
    _log('Sync: $successfulTypes/$_coreMetrics.length metrics, $completeness%');

    // Robust deduplication: type + timestamps + source + value
    final seen = <String>{};
    final deduplicated = allMetrics.where((metric) {
      // Include date_from/date_to for intervals, source, and value to avoid dropping valid data
      final dateFrom = metric.metadata['date_from'] ?? '';
      final dateTo = metric.metadata['date_to'] ?? metric.timestamp.toIso8601String();
      final key = '${metric.type}|$dateFrom|$dateTo|${metric.source}|${metric.value.toStringAsFixed(2)}';
      
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      return true;
    }).toList();

    if (deduplicated.isEmpty) {
      _log('No data retrieved');
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
