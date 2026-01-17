import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../foundation/baseline_calculator_v2.dart';

/// Endurance Capacity Result
class EnduranceCapacityResult {
  final double score; // 0-100
  final double weeklyVolume;
  final String confidence;
  final Map<String, dynamic> components;
  
  const EnduranceCapacityResult({
    required this.score,
    required this.weeklyVolume,
    required this.confidence,
    required this.components,
  });
}

/// Score #4: Endurance Capacity (0-100)
/// Aerobic work capacity and sustained activity ability
class EnduranceCapacityCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  EnduranceCapacityCalculator({
    required this.db,
    required this.baseline,
  });
  
  /// Calculate endurance capacity for a given date
  Future<EnduranceCapacityResult> calculate({
    required String userEmail,
    required DateTime date,
  }) async {
    // Get 7-day volume
    final weeklyVolume = await _getWeeklyDistance(userEmail, date);
    
    // Get walking heart rate
    final whrValue = await _getLatestValue(userEmail, 'WALKING_HEART_RATE', date);
    final whrBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'WALKING_HEART_RATE',
      endDate: date,
    );
    final zWHR = baseline.computeZScore(whrValue, whrBaseline);
    
    // Intensity score (lower WHR = better economy)
    final intensityScore = (50 - 12.5 * zWHR).clamp(0, 100);
    
    // Get exercise time 7-day
    final exerciseTime7d = await _getWeeklyExerciseTime(userEmail, date);
    
    // Time score (percentile-based, using simple normalization for now)
    final timeScore = _normalizeToPercentile(exerciseTime7d, 0, 600); // 0-10 hours
    
    // Volume score (percentile-based)
    final volumeScore = _normalizeToPercentile(weeklyVolume, 0, 100000); // 0-100km
    
    // Final endurance = 45% volume + 25% time + 30% intensity
    final enduranceScore = (0.45 * volumeScore + 
                           0.25 * timeScore + 
                           0.30 * intensityScore)
        .clamp(0, 100);
    
    final confidence = weeklyVolume > 0 ? 'high' : 'medium';
    
    return EnduranceCapacityResult(
      score: enduranceScore.toDouble(),
      weeklyVolume: weeklyVolume,
      confidence: confidence,
      components: {
        'weekly_volume_km': (weeklyVolume / 1000.0).toDouble(),
        'exercise_time_min': exerciseTime7d.toDouble(),
        'intensity_score': intensityScore.toDouble(),
        'time_score': timeScore.toDouble(),
        'volume_score': volumeScore.toDouble(),
      },
    );
  }
  
  /// Get weekly distance (7 days)
  Future<double> _getWeeklyDistance(String userEmail, DateTime date) async {
    final startDate = date.subtract(Duration(days: 7));
    
    final result = await db.query(
      'health_metrics',
      where: '''
        user_email = ? 
        AND metric_type = ? 
        AND timestamp >= ? 
        AND timestamp <= ?
      ''',
      whereArgs: [
        userEmail,
        'DISTANCE_WALKING_RUNNING',
        startDate.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      ],
    );
    
    double sum = 0.0;
    for (var row in result) {
      sum += (row['value'] as num).toDouble();
    }
    return sum;
  }
  
  /// Get weekly exercise time (minutes)
  Future<double> _getWeeklyExerciseTime(String userEmail, DateTime date) async {
    final startDate = date.subtract(Duration(days: 7));
    
    final result = await db.query(
      'health_metrics',
      where: '''
        user_email = ? 
        AND metric_type = ? 
        AND timestamp >= ? 
        AND timestamp <= ?
      ''',
      whereArgs: [
        userEmail,
        'EXERCISE_TIME',
        startDate.millisecondsSinceEpoch,
        date.millisecondsSinceEpoch,
      ],
    );
    
    double sum = 0.0;
    for (var row in result) {
      sum += (row['value'] as num).toDouble();
    }
    return sum;
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
  
  /// Simple percentile normalization
  double _normalizeToPercentile(double value, double min, double max) {
    return ((value - min) / (max - min) * 100).clamp(0, 100);
  }
}
