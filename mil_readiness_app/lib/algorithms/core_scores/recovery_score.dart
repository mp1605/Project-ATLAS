import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../services/last_sleep_service.dart';
import '../../models/user_profile.dart';
import '../foundation/baseline_calculator_v2.dart';
import '../foundation/data_sufficiency_checker.dart';

/// Recovery Score Result
class RecoveryScoreResult {
  final double score; // 0-100
  final String confidence; // 'high', 'medium', 'low'
  final Map<String, dynamic> components;
  final List<String> topContributors;
  
  const RecoveryScoreResult({
    required this.score,
    required this.confidence,
    required this.components,
    required this.topContributors,
  });
}

/// Score #2: Recovery Score (0-100)
/// Measures autonomic recovery and physiologic strain vs personal baseline
class RecoveryScoreCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  final DataSufficiencyChecker dataCheck;
  
  RecoveryScoreCalculator({
    required this.db,
    required this.baseline,
    required this.dataCheck,
  });
  
  /// Calculate recovery score for a given date
  Future<RecoveryScoreResult> calculate({
    required String userEmail,
    required DateTime date,
  }) async {
    // Check data sufficiency
    final quality = await dataCheck.checkMultiple(
      userEmail: userEmail,
      metricTypes: ['HRV_RMSSD', 'RESTING_HEART_RATE', 'BODY_TEMPERATURE'],
      startDate: date.subtract(Duration(hours: 24)),
      endDate: date,
    );
    
    final confidence = dataCheck.getOverallConfidence(quality);
    
    // Use LastSleepService for aggregated sleep stages
    final lastSleep = await LastSleepService.getLastSleep(userEmail);
    final sleepDeep = lastSleep?.deepMinutes.toDouble() ?? 0.0;
    final sleepAsleep = lastSleep?.totalMinutes.toDouble() ?? 0.0;
    
    // Get latest values for physiological markers
    final hrvValue = await _getLatestValue(userEmail, 'HRV_RMSSD', date);
    final sdnnValue = await _getLatestValue(userEmail, 'HRV_SDNN', date);
    final rhrValue = await _getLatestValue(userEmail, 'RESTING_HEART_RATE', date);
    final tempValue = await _getLatestValue(userEmail, 'BODY_TEMPERATURE', date);
    final edaValue = await _getLatestValue(userEmail, 'ELECTRODERMAL_ACTIVITY', date);

    // Get baselines
    final hrvBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'HRV_RMSSD',
      endDate: date,
    );
    final sdnnBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'HRV_SDNN',
      endDate: date,
    );
    final rhrBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'RESTING_HEART_RATE',
      endDate: date,
    );
    final tempBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'BODY_TEMPERATURE',
      endDate: date,
    );
    
    // Calculate z-scores
    final zHRV = baseline.computeZScore(hrvValue, hrvBaseline);
    final zSDNN = baseline.computeZScore(sdnnValue, sdnnBaseline);
    final zRHR = baseline.computeZScore(rhrValue, rhrBaseline);
    final zTemp = baseline.computeZScore(tempValue, tempBaseline);
    final zEDA = edaValue > 0 ? await _computeEDAZScore(userEmail, edaValue, date) : 0.0;
    
    // Component 1: HRV Score
    final hrvZ = 0.6 * zHRV + 0.4 * zSDNN;
    final hrvScore = (50 + 12.5 * hrvZ).clamp(0, 100);
    
    // Component 2: RHR Score (inverted - lower is better)
    final rhrScore = (50 - 12.5 * zRHR).clamp(0, 100);
    
    // Component 3: Temperature Score (penalize deviation both directions)
    final tempScore = (50 - 20 * zTemp.abs()).clamp(0, 100);
    
    // Component 4: Stress Score (EDA)
    final stressScore = (50 - 12.5 * zEDA).clamp(0, 100);
    
    // Component 5: Sleep Boost
    final sleepBoost = sleepAsleep > 0 
        ? 10 * math.min(1.0, sleepDeep / (0.18 * sleepAsleep + 0.001))
        : 0.0;
    
    // Check if EDA is available
    final hasEDA = edaValue > 0;
    
    // Final recovery score
    double recoveryScore;
    if (hasEDA) {
      recoveryScore = 0.35 * hrvScore + 
                     0.25 * rhrScore + 
                     0.20 * tempScore + 
                     0.10 * stressScore + 
                     0.10 * (50 + sleepBoost);
    } else {
      // Redistribute EDA weight to HRV
      recoveryScore = 0.45 * hrvScore + 
                     0.25 * rhrScore + 
                     0.20 * tempScore + 
                     0.10 * (50 + sleepBoost);
    }
    
    recoveryScore = recoveryScore.clamp(0, 100);
    
    // Build components map with proper typing
    final Map<String, double> components = {
      'hrv': hrvScore.toDouble(),
      'rhr': rhrScore.toDouble(),
      'temperature': tempScore.toDouble(),
      'stress': stressScore.toDouble(),
      'sleep_boost': sleepBoost.toDouble(),
    };
    
    // Identify top contributors
    final topContributors = _getTopContributors(components);
    
    return RecoveryScoreResult(
      score: recoveryScore,
      confidence: confidence,
      components: components,
      topContributors: topContributors,
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
  
  /// Compute EDA z-score
  Future<double> _computeEDAZScore(String userEmail, double value, DateTime date) async {
    final edaBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'ELECTRODERMAL_ACTIVITY',
      endDate: date,
    );
    return baseline.computeZScore(value, edaBaseline);
  }
  
  /// Identify top 3 contributors (positive or negative)
  List<String> _getTopContributors(Map<String, double> components) {
    final sorted = components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(3).map((e) => e.key).toList();
  }
}
