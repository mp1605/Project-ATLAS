import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../services/last_sleep_service.dart';
import '../../services/sleep_source_resolver.dart';
import '../../models/user_profile.dart';
import '../../models/manual_log.dart';
import '../../repositories/manual_log_repository.dart';
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
    
    // Get resolved sleep (manual or auto) for total sleep duration
    final dateStr = SleepSourceResolver.getTodayWakeDate();
    final resolved = await SleepSourceResolver.getSleepForDate(userEmail, dateStr);
    final sleepAsleep = resolved.minutes.toDouble();
    
    // Get auto sleep for sleep stages (fallback to 0 for manual)
    final lastSleep = await LastSleepService.getLastSleep(userEmail);
    final sleepDeep = lastSleep?.deepMinutes.toDouble() ?? 0.0;
    
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
    
    // Component 6: Hydration Score (from manual logs)
    final hydrationScore = await _getHydrationScore(userEmail, date);
    
    // Component 7: Nutrition Score (from manual logs)
    final nutritionScore = await _getNutritionScore(userEmail, date);
    
    // Component 8: Manual Stress Score (from manual logs, inverted)
    final manualStressScore = await _getManualStressScore(userEmail, date);
    
    // Check if EDA is available
    final hasEDA = edaValue > 0;
    
    // Final recovery score with manual log integration
    double recoveryScore;
    if (hasEDA) {
      // With EDA: integrate all components
      recoveryScore = 0.25 * hrvScore +          // HRV (reduced from 35%)
                     0.20 * rhrScore +           // RHR (reduced from 25%)
                     0.15 * tempScore +          // Temp (reduced from 20%)
                     0.08 * stressScore +        // EDA stress (reduced from 10%)
                     0.08 * (50 + sleepBoost) +  // Sleep (reduced from 10%)
                     0.10 * hydrationScore +     // Hydration (new)
                     0.07 * nutritionScore +     // Nutrition (new)
                     0.07 * manualStressScore;   // Manual stress (new)
    } else {
      // Without EDA: redistribute weight
      recoveryScore = 0.30 * hrvScore +          // HRV
                     0.20 * rhrScore +           // RHR
                     0.15 * tempScore +          // Temp
                     0.10 * (50 + sleepBoost) +  // Sleep
                     0.10 * hydrationScore +     // Hydration
                     0.08 * nutritionScore +     // Nutrition
                     0.07 * manualStressScore;   // Manual stress
    }
    
    recoveryScore = recoveryScore.clamp(0, 100);
    
    // Build components map with proper typing
    final Map<String, double> components = {
      'hrv': hrvScore.toDouble(),
      'rhr': rhrScore.toDouble(),
      'temperature': tempScore.toDouble(),
      'stress': stressScore.toDouble(),
      'sleep_boost': sleepBoost.toDouble(),
      'hydration': hydrationScore.toDouble(),
      'nutrition': nutritionScore.toDouble(),
      'manual_stress': manualStressScore.toDouble(),
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
  
  /// Get hydration score from manual logs
  /// Target: 8 glasses per day
  Future<double> _getHydrationScore(String userEmail, DateTime date) async {
    final logs = await ManualLogRepository.getLogsForDate(
      userEmail: userEmail,
      date: date,
      logType: 'hydration',
    );
    
    if (logs.isEmpty) {
      return 50.0; // Neutral score if no data
    }
    
    // Sum all hydration entries for the day
    double totalGlasses = 0.0;
    for (final log in logs) {
      totalGlasses += log.value;
    }
    
    // Target: 8 glasses, score 0-100
    // 8+ glasses = 100, 0 glasses = 0
    final score = (totalGlasses / 8.0 * 100).clamp(0, 100);
    
    print('💧 Hydration score: $totalGlasses glasses → $score');
    return score.toDouble();
  }
  
  /// Get nutrition score from manual logs
  /// Quality rating: 1-5 scale
  Future<double> _getNutritionScore(String userEmail, DateTime date) async {
    final logs = await ManualLogRepository.getLogsForDate(
      userEmail: userEmail,
      date: date,
      logType: 'nutrition',
    );
    
    if (logs.isEmpty) {
      return 50.0; // Neutral score if no data
    }
    
    // Average nutrition quality for the day
    double totalQuality = 0.0;
    for (final log in logs) {
      totalQuality += log.value;
    }
    final avgQuality = totalQuality / logs.length;
    
    // Map 1-5 scale to 0-100
    final score = ((avgQuality - 1) / 4.0 * 100).clamp(0, 100);
    
    print('🍎 Nutrition score: avg quality $avgQuality → $score');
    return score.toDouble();
  }
  
  /// Get manual stress score from manual logs
  /// Stress rating: 1-5 scale (inverted - higher stress = lower score)
  Future<double> _getManualStressScore(String userEmail, DateTime date) async {
    final logs = await ManualLogRepository.getLogsForDate(
      userEmail: userEmail,
      date: date,
      logType: 'stress',
    );
    
    if (logs.isEmpty) {
      return 50.0; // Neutral score if no data
    }
    
    // Average stress for the day
    double totalStress = 0.0;
    for (final log in logs) {
      totalStress += log.value;
    }
    final avgStress = totalStress / logs.length;
    
    // Invert: 1 (low stress) = 100, 5 (high stress) = 0
    final score = (1 - (avgStress - 1) / 4.0) * 100;
    
    print('😰 Manual stress score: avg stress $avgStress → $score');
    return score.clamp(0, 100).toDouble();
  }
}
