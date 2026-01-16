import 'dart:math';
import '../database/health_data_repository.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/readiness/baseline.dart';
import '../database/secure_database_manager.dart';

/// Calculates 28-day rolling baseline statistics using robust methods
/// 
/// Uses median and MAD (Median Absolute Deviation) instead of mean/SD
/// to handle outliers gracefully.
class BaselineCalculator {
  /// Calculate median of a list of values
  static double median(List<double> values) {
    if (values.isEmpty) return 0;
    
    final sorted = List<double>.from(values)..sort();
    final len = sorted.length;
    
    if (len.isOdd) {
      return sorted[len ~/ 2];
    } else {
      return (sorted[len ~/ 2 - 1] + sorted[len ~/ 2]) / 2.0;
    }
  }

  /// Calculate MAD (Median Absolute Deviation)
  /// 
  /// MAD = median(|value - median(values)|)
  static double mad(List<double> values) {
    if (values.isEmpty) return 0;
    
    final med = median(values);
    final deviations = values.map((v) => (v - med).abs()).toList();
    
    return median(deviations);
  }

  /// Calculate p-th percentile
  static double percentile(List<double> values, double p) {
    if (values.isEmpty) return 0;
    if (p <= 0) return values.reduce(min);
    if (p >= 100) return values.reduce(max);
    
    final sorted = List<double>.from(values)..sort();
    final index = (p / 100.0) * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    
    if (lower == upper) return sorted[lower];
    
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  /// Get or compute baseline for a specific metric type
  /// 
  /// First checks cache (database), then computes if stale/missing.
  static Future<Baseline?> getBaseline({
    required String userEmail,
    required String metricType,
    Duration window = const Duration(days: 28),
    bool forceRecompute = false,
  }) async {
    // Try to get cached baseline
    if (!forceRecompute) {
      final cached = await _getCachedBaseline(userEmail, metricType);
      if (cached != null && cached.isValid && !cached.isStale) {
        return cached;
      }
    }

    // Compute fresh baseline
    return await _computeBaseline(
      userEmail: userEmail,
      metricType: metricType,
      window: window,
    );
  }

  /// Compute baseline from raw health data
  static Future<Baseline?> _computeBaseline({
    required String userEmail,
    required String metricType,
    required Duration window,
  }) async {
    final end = DateTime.now();
    final start = end.subtract(window);

    // Get raw metrics from database
    final metrics = await HealthDataRepository.getMetricsInRange(
      userEmail,
      start: start,
      end: end,
      metricType: metricType,
    );

    if (metrics.isEmpty) {
      print('⚠️ No data for $metricType in ${window.inDays}-day window');
      return null;
    }

    // Extract values
    final values = metrics.map((m) => m.value).toList();

    // Compute statistics
    final medianVal = median(values);
    final madVal = mad(values);

    final baseline = Baseline(
      metricType: metricType,
      median: medianVal,
      mad: madVal,
      windowDays: window.inDays,
      sampleCount: values.length,
      updatedAt: DateTime.now(),
    );

    // Cache in database
    await _cacheBaseline(userEmail, baseline);

    print('✅ Baseline computed for $metricType: $baseline');
    return baseline;
  }

  /// Get cached baseline from database
  static Future<Baseline?> _getCachedBaseline(
    String userEmail,
    String metricType,
  ) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final results = await db.query(
      'baselines',
      where: 'user_email = ? AND metric_type = ?',
      whereArgs: [userEmail, metricType],
    );

    if (results.isEmpty) return null;
    
    return Baseline.fromMap(results.first);
  }

  /// Save baseline to database (cache)
  static Future<void> _cacheBaseline(String userEmail, Baseline baseline) async {
    final db = await SecureDatabaseManager.instance.database;
    
    await db.insert(
      'baselines',
      baseline.toMap(userEmail),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Invalidate cached baselines (force recompute on next access)
  static Future<void> invalidateBaselines({
    required String userEmail,
    String? metricType,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    if (metricType != null) {
      await db.delete(
        'baselines',
        where: 'user_email = ? AND metric_type = ?',
        whereArgs: [userEmail, metricType],
      );
    } else {
      await db.delete(
        'baselines',
        where: 'user_email = ?',
        whereArgs: [userEmail],
      );
    }
  }

  /// Get all baselines for user (for debugging)
  static Future<List<Baseline>> getAllBaselines(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final results = await db.query(
      'baselines',
      where: 'user_email = ?',
      whereArgs: [userEmail],
    );

    return results.map((m) => Baseline.fromMap(m)).toList();
  }
}
