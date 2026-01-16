import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../foundation/baseline_calculator_v2.dart';

/// Cardiovascular Fitness Result
class CardiovascularFitnessResult {
  final double score; // 0-100
  final String method; // 'vo2max' or 'economy'
  final String confidence;
  
  const CardiovascularFitnessResult({
    required this.score,
    required this.method,
    required this.confidence,
  });
}

/// Score #6: Cardiovascular Fitness (0-100)
/// Approximates aerobic fitness using available wearable indicators
class CardiovascularFitnessCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  CardiovascularFitnessCalculator({
    required this.db,
    required this.baseline,
  });
  
  /// Calculate cardiovascular fitness for a given date
  Future<CardiovascularFitnessResult> calculate({
    required String userEmail,
    required DateTime date,
  }) async {
    // Try to get VO2max if available (not commonly available from Apple Watch)
    // For now, use economy-based fallback
    
    // Get RHR
    final rhrValue = await _getLatestValue(userEmail, 'RESTING_HEART_RATE', date);
    final rhrBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'RESTING_HEART_RATE',
      endDate: date,
    );
    final zRHR = baseline.computeZScore(rhrValue, rhrBaseline);
    
    // Get Walking HR
    final whrValue = await _getLatestValue(userEmail, 'WALKING_HEART_RATE', date);
    final whrBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'WALKING_HEART_RATE',
      endDate: date,
    );
    final zWHR = baseline.computeZScore(whrValue, whrBaseline);
    
    // Economy index (lower heart rates = better fitness)
    final econ = zRHR + 0.8 * zWHR;
    
    // Cardio fitness = 70 - 10×Econ
    final cardioFit = (70 - 10 * econ).clamp(0, 100);
    
    final confidence = (rhrValue > 0 && whrValue > 0) ? 'medium' : 'low';
    
    return CardiovascularFitnessResult(
      score: cardioFit.toDouble(),
      method: 'economy',
      confidence: confidence,
    );
  }
  
  /// Get latest metric value
  Future<double> _getLatestValue(String userEmail, String metricType, DateTime date) async {
    final result = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
      whereArgs: [
        userEmail,
        metricType,
        date.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    if (result.isEmpty) return 0.0;
    return (result.first['value'] as num).toDouble();
  }
}
