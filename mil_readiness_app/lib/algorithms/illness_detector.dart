import '../database/secure_database_manager.dart';

import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/readiness/illness_result.dart';
import 'baseline_calculator.dart';
import 'zscore_calculator.dart';

/// Detects illness/strain probability using physiological signals (D)
/// 
/// Uses logistic regression on z-scores:
/// u = a1*z_RHR - a2*z_HRV + a3*z_RR + a4*(H/5)
/// p_ill = σ(u) = 1 / (1 + e^(-u))
/// penalty = 30 * p_ill
class IllnessDetector {
  // Default weights (tunable via calibration G2)
  static const double weightRHR = 1.0;    // Elevated RHR = bad
  static const double weightHRV = 1.0;    // Low HRV = bad (negative sign in formula)
  static const double weightRR = 0.8;     // Elevated RR = bad
  static const double weightHypoxia = 0.5; // Low SpO2 = bad

  /// Detect illness/strain for a specific date
  static Future<IllnessResult?> detect({
    required String userEmail,
    required DateTime date,
  }) async {
    // Get z-scores for the day
    final zHRV = await _getHRVZScore(userEmail, date);
    final zRHR = await _getRHRZScore(userEmail, date);
    final zRR = await _getRRZScore(userEmail, date);
    final hypoxia = await _getHypoxiaMetric(userEmail, date);

    // If missing critical data, return null
    if (zHRV == null || zRHR == null) {
      print('⚠️ Missing HRV or RHR data for illness detection on $date');
      return null;
    }

    // Default RR and hypoxia to 0 if missing
    final safeZRR = zRR ?? 0.0;
    final safeHypoxia = hypoxia ?? 0.0;

    // Linear combination (equation D)
    final u = weightRHR * zRHR - 
              weightHRV * zHRV +  // Note: minus sign because low HRV = bad
              weightRR * safeZRR +
              weightHypoxia * (safeHypoxia / 5.0);

    // Logistic transform to probability
    final pIll = _sigmoid(u);

    // Calculate penalty (0-30 points)
    final penalty = 30.0 * pIll;

    // High risk threshold
    final isHigh = pIll > 0.65;

    final result = IllnessResult(
      probability: pIll,
      penalty: penalty,
      isHigh: isHigh,
      zHRV: zHRV,
      zRHR: zRHR,
      zRR: safeZRR,
      hypoxiaMetric: safeHypoxia,
    );

    print('✅ Illness detection for $date: $result');
    return result;
  }

  /// Get HRV z-score for date
  static Future<double?> _getHRVZScore(String userEmail, DateTime date) async {
    final hrv = await _getMetricValue(userEmail, date, 'HEART_RATE_VARIABILITY_SDNN');
    if (hrv == null) return null;

    return await ZScoreCalculator.hrvZScore(
      userEmail: userEmail,
      hrvValue: hrv,
    );
  }

  /// Get RHR z-score for date
  static Future<double?> _getRHRZScore(String userEmail, DateTime date) async {
    final rhr = await _getMetricValue(userEmail, date, 'RESTING_HEART_RATE');
    if (rhr == null) return null;

    return await ZScoreCalculator.rhrZScore(
      userEmail: userEmail,
      rhrValue: rhr,
    );
  }

  /// Get respiratory rate z-score for date
  static Future<double?> _getRRZScore(String userEmail, DateTime date) async {
    final rr = await _getMetricValue(userEmail, date, 'RESPIRATORY_RATE');
    if (rr == null) return null;

    return await ZScoreCalculator.rrZScore(
      userEmail: userEmail,
      rrValue: rr,
    );
  }

  /// Calculate hypoxia metric from SpO2 (equation B3)
  /// 
  /// H = max(0, 95 - SpO2_median) + 2 * max(0, 92 - SpO2_p10)
  static Future<double?> _getHypoxiaMetric(String userEmail, DateTime date) async {
    final spo2Values = await _getMetricValues(userEmail, date, 'BLOOD_OXYGEN');
    
    if (spo2Values.isEmpty) return null;

    // Calculate median and 10th percentile
    final median = BaselineCalculator.median(spo2Values);
    final p10 = BaselineCalculator.percentile(spo2Values, 10);

    // Hypoxia metric
    final h = max(0.0, 95 - median) + 2 * max(0.0, 92 - p10);

    return h;
  }

  /// Get single metric value for a specific date
  static Future<double?> _getMetricValue(
    String userEmail,
    DateTime date,
    String metricType,
  ) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(Duration(days: 1));

    final results = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        userEmail,
        metricType,
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return (results.first['value'] as num).toDouble();
  }

  /// Get all metric values for a specific date (for percentile calculation)
  static Future<List<double>> _getMetricValues(
    String userEmail,
    DateTime date,
    String metricType,
  ) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(Duration(days: 1));

    final results = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        userEmail,
        metricType,
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
      ],
    );

    return results.map((r) => (r['value'] as num).toDouble()).toList();
  }

  /// Sigmoid function σ(x) = 1 / (1 + e^(-x))
  static double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }
}
