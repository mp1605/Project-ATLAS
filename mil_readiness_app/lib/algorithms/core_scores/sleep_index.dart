import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/user_profile.dart';
import '../foundation/baseline_calculator_v2.dart';

/// Sleep Index Result
class SleepIndexResult {
  final double score; // 0-100
  final Map<String, double> components;
  final String confidence;
  
  const SleepIndexResult({
    required this.score,
    required this.components,
    required this.confidence,
  });
}

/// Score #5: Sleep Index (0-100)
/// Sleep quality and quantity for cognitive + physical performance
class SleepIndexCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  SleepIndexCalculator({
    required this.db,
    required this.baseline,
  });
  
  /// Calculate sleep index for a given date
  Future<SleepIndexResult> calculate({
    required String userEmail,
    required DateTime date,
    required UserProfile profile,
  }) async {
    // Get sleep metrics
    final sleepAsleep = await _getLatestValue(userEmail, 'SLEEP_ASLEEP', date);
    final sleepInBed = await _getLatestValue(userEmail, 'SLEEP_IN_BED', date);
    final sleepDeep = await _getLatestValue(userEmail, 'SLEEP_DEEP', date);
    final sleepREM = await _getLatestValue(userEmail, 'SLEEP_REM', date);
    final sleepAwake = await _getLatestValue(userEmail, 'SLEEP_AWAKE', date);
    
    // Get physiological metrics
    final rhrValue = await _getLatestValue(userEmail, 'RESTING_HEART_RATE', date);
    final tempValue = await _getLatestValue(userEmail, 'BODY_TEMPERATURE', date);
    
    // Get baselines for physio metrics
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
    
    final zRHR = baseline.computeZScore(rhrValue, rhrBaseline);
    final zTemp = baseline.computeZScore(tempValue, tempBaseline);
    
    // Component 1: Duration Score
    final targetSleep = profile.targetSleep.toDouble();
    final durationScore = (100 * math.min(1.0, sleepAsleep / targetSleep))
        .clamp(0, 100);
    
    // Component 2: Efficiency Score
    final efficiency = sleepAsleep / (sleepInBed + 0.001);
    final efficiencyScore = (100 * _clamp01((efficiency - 0.75) / 0.20))
        .clamp(0, 100);
    
    // Component 3: Stage Score
    final deepFrac = sleepDeep / (sleepAsleep + 0.001);
    final remFrac = sleepREM / (sleepAsleep + 0.001);
    final stageScore = (50 * _clamp01(deepFrac / 0.18) + 
                       50 * _clamp01(remFrac / 0.22))
        .clamp(0, 100);
    
    // Component 4: Fragmentation Score
    final awakeFrac = sleepAwake / (sleepAsleep + 0.001);
    final fragScore = (100 - 100 * _clamp01((awakeFrac - 0.05) / 0.10))
        .clamp(0, 100);
    
    // Component 5: Physiological Penalty
    final physioPenalty = 15 * math.max(0, zRHR) + 
                         15 * zTemp.abs();
    
    // Final sleep index
    final sleepIndex = (0.30 * durationScore + 
                       0.20 * efficiencyScore + 
                       0.20 * stageScore + 
                       0.20 * fragScore - 
                       physioPenalty)
        .clamp(0, 100);
    
    // Determine confidence
    final confidence = sleepAsleep > 0 ? 'high' : 'low';
    
    return SleepIndexResult(
      score: sleepIndex.toDouble(),
      components: {
        'duration': durationScore.toDouble(),
        'efficiency': efficiencyScore.toDouble(),
        'stages': stageScore.toDouble(),
        'fragmentation': fragScore.toDouble(),
        'physio_penalty': physioPenalty,
      },
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
  
  /// Clamp value to [0, 1]
  double _clamp01(double value) {
    return value.clamp(0.0, 1.0);
  }
}
