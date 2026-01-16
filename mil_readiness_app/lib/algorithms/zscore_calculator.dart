import '../database/secure_database_manager.dart';

import 'dart:math';
import 'baseline_calculator.dart';
import '../models/readiness/baseline.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Calculates robust z-scores using median and MAD
/// 
/// Formula: z = (value - median) / (1.4826 * MAD + ε)
/// 
/// The 1.4826 scaling factor makes MAD comparable to standard deviation
/// for normal distributions.
class ZScoreCalculator {
  /// Scaling constant to make MAD comparable to SD
  static const double madScale = 1.4826;
  
  /// Small epsilon to prevent division by zero
  static const double epsilon = 0.001;

  /// Calculate robust z-score given baseline statistics
  static double calculateZScore({
    required double currentValue,
    required double median,
    required double mad,
  }) {
    final denominator = madScale * mad + epsilon;
    return (currentValue - median) / denominator;
  }

  /// Calculate z-score from Baseline object
  static double fromBaseline({
    required double currentValue,
    required Baseline baseline,
  }) {
    return calculateZScore(
      currentValue: currentValue,
      median: baseline.median,
      mad: baseline.mad,
    );
  }

  /// Get HRV z-score (higher = better recovery)
  /// 
  /// HRV must be log-transformed first!
  static Future<double?> hrvZScore({
    required String userEmail,
    required double hrvValue,
  }) async {
    // Log transform HRV (as per B1)
    final logHRV = log(hrvValue);
    
    // Get baseline for log-transformed HRV
    final baseline = await BaselineCalculator.getBaseline(
      userEmail: userEmail,
      metricType: 'HEART_RATE_VARIABILITY_SDNN_LOG',
    );

    if (baseline == null || !baseline.isValid) {
      print('⚠️ No valid HRV baseline for $userEmail');
      return null;
    }

    final z = fromBaseline(currentValue: logHRV, baseline: baseline);
    
    print('📊 HRV z-score: $hrvValue ms → log=$logHRV → z=$z');
    return z;
  }

  /// Get Resting HR z-score (lower = better recovery, so inverted)
  static Future<double?> rhrZScore({
    required String userEmail,
    required double rhrValue,
  }) async {
    final baseline = await BaselineCalculator.getBaseline(
      userEmail: userEmail,
      metricType: 'RESTING_HEART_RATE',
    );

    if (baseline == null || !baseline.isValid) {
      print('⚠️ No valid RHR baseline for $userEmail');
      return null;
    }

    final z = fromBaseline(currentValue: rhrValue, baseline: baseline);
    
    print('📊 RHR z-score: $rhrValue bpm → z=$z');
    return z;
  }

  /// Get Respiratory Rate z-score (during sleep)
  static Future<double?> rrZScore({
    required String userEmail,
    required double rrValue,
  }) async {
    final baseline = await BaselineCalculator.getBaseline(
      userEmail: userEmail,
      metricType: 'RESPIRATORY_RATE',
    );

    if (baseline == null || !baseline.isValid) {
      print('⚠️ No valid RR baseline for $userEmail');
      return null;
    }

    final z = fromBaseline(currentValue: rrValue, baseline: baseline);
    
    print('📊 RR z-score: $rrValue breaths/min → z=$z');
    return z;
  }

  /// Compute log-transformed HRV baseline
  /// 
  /// This is a helper to compute baselines for log(HRV) values.
  static Future<Baseline?> computeLogHRVBaseline({
    required String userEmail,
    Duration window = const Duration(days: 28),
  }) async {
    // This will be called during initial setup or baseline refresh
    // We need to get raw HRV values, log-transform them, then compute baseline
    
    final end = DateTime.now();
    final start = end.subtract(window);

    // Get raw HRV metrics
    final db = await SecureDatabaseManager.instance.database;
    final results = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        userEmail,
        'HEART_RATE_VARIABILITY_SDNN',
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );

    if (results.isEmpty) {
      print('⚠️ No HRV data in ${window.inDays}-day window');
      return null;
    }

    // Log-transform values
    final logValues = results
        .map((r) => (r['value'] as num).toDouble())
        .where((v) => v > 0) // Filter out any zero/negative values
        .map((v) => log(v))
        .toList();

    if (logValues.isEmpty) return null;

    // Compute baseline statistics
    final medianVal = BaselineCalculator.median(logValues);
    final madVal = BaselineCalculator.mad(logValues);

    final baseline = Baseline(
      metricType: 'HEART_RATE_VARIABILITY_SDNN_LOG',
      median: medianVal,
      mad: madVal,
      windowDays: window.inDays,
      sampleCount: logValues.length,
      updatedAt: DateTime.now(),
    );

    // Cache in database
    await _cacheBaseline(userEmail, baseline);

    print('✅ Log-HRV baseline computed: $baseline');
    return baseline;
  }

  static Future<void> _cacheBaseline(String userEmail, Baseline baseline) async {
    final db = await SecureDatabaseManager.instance.database;
    await db.insert(
      'baselines',
      baseline.toMap(userEmail),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
