import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/user_profile.dart';
import 'recovery_score.dart';
import 'fatigue_index.dart';
import 'sleep_index.dart';

/// Overall Readiness Result
class OverallReadinessResult {
  final double score; // 0-100
  final String category; // 'GO', 'CAUTION', 'LIMITED', 'STOP'
  final String confidence;
  final Map<String, double> componentScores;
  
  const OverallReadinessResult({
    required this.score,
    required this.category,
    required this.confidence,
    required this.componentScores,
  });
}

/// Score #1: Overall Readiness (0-100)
/// Master score combining recovery, sleep, cardio-resp, fatigue, and safety
class OverallReadinessCalculator {
  final Database db;
  final RecoveryScoreCalculator recoveryCalc;
  final FatigueIndexCalculator fatigueCalc;
  final SleepIndexCalculator sleepCalc;
  
  OverallReadinessCalculator({
    required this.db,
    required this.recoveryCalc,
    required this.fatigueCalc,
    required this.sleepCalc,
  });
  
  /// Calculate overall readiness for a given date
  Future<OverallReadinessResult> calculate({
    required String userEmail,
    required DateTime date,
    required UserProfile profile,
  }) async {
    // Calculate component scores
    final recovery = await recoveryCalc.calculate(
      userEmail: userEmail,
      date: date,
    );
    
    final sleep = await sleepCalc.calculate(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    
    final fatigue = await fatigueCalc.calculate(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    
    // Simplified cardio-resp stability (placeholder for now)
    final cardioResp = await _calculateCardioRespStability(
      userEmail: userEmail,
      date: date,
    );
    
    // Simplified cardiac safety penalty (placeholder for now)
    final safetyPenalty = await _calculateSafetyPenalty(
      userEmail: userEmail,
      date: date,
    );
    
    // Overall readiness formula
    // Readiness = 0.30×Recovery + 0.25×Sleep + 0.20×CardioResp 
    //           + 0.20×(100-Fatigue) + 0.05×(100-SafetyPenalty)
    final readinessBase = 0.30 * recovery.score + 
                         0.25 * sleep.score + 
                         0.20 * cardioResp + 
                         0.20 * (100 - fatigue.score) + 
                         0.05 * (100 - safetyPenalty);
    
    var readiness = readinessBase.clamp(0, 100);
    
    // Safety override: if safety penalty >= 60, force readiness <= 39 (STOP)
    if (safetyPenalty >= 60) {
      readiness = math.min(readiness, 39);
    }
    
    // Determine category
    final category = _categorize(readiness.toDouble());
    
    // Determine overall confidence
    final confidence = _determineConfidence([
      recovery.confidence,
      sleep.confidence,
      fatigue.confidence,
    ]);
    
    return OverallReadinessResult(
      score: readiness.toDouble(),
      category: category,
      confidence: confidence,
      componentScores: {
        'recovery': recovery.score,
        'sleep': sleep.score,
        'fatigue': fatigue.score,
        'cardio_resp': cardioResp,
        'safety_penalty': safetyPenalty,
      },
    );
  }
  
  /// Simplified cardio-respiratory stability
  /// Full implementation will be in Phase 3
  Future<double> _calculateCardioRespStability({
    required String userEmail,
    required DateTime date,
  }) async {
    // Placeholder: return high score (85) for now
    // TODO: Implement full Score #9 in Phase 3
    return 85.0;
  }
  
  /// Simplified cardiac safety penalty
  /// Full implementation will be in Phase 3
  Future<double> _calculateSafetyPenalty({
    required String userEmail,
    required DateTime date,
  }) async {
    // Check for heart rate events in last 24 hours
    final startDate = date.subtract(Duration(hours: 24));
    
    final highEvents = await _countEvents(userEmail, 'HIGH_HEART_RATE_EVENT', startDate, date);
    final lowEvents = await _countEvents(userEmail, 'LOW_HEART_RATE_EVENT', startDate, date);
    final irregEvents = await _countEvents(userEmail, 'IRREGULAR_HEART_RATE_EVENT', startDate, date);
    
    final eventCount = highEvents + lowEvents + 2 * irregEvents;
    
    final penalty = (20 * math.min(5, eventCount)).toDouble().clamp(0, 100);
    
    // If any irregular event, minimum penalty of 40
    if (irregEvents > 0) {
      return math.max(penalty.toDouble(), 40.0);
    }
    
    return penalty.toDouble();
  }
  
  /// Count heart rate events
  Future<int> _countEvents(String userEmail, String metricType, DateTime start, DateTime end) async {
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
        metricType,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
    
    return result.length;
  }
  
  /// Categorize readiness score
  String _categorize(double score) {
    if (score >= 80) return 'GO';
    if (score >= 60) return 'CAUTION';
    if (score >= 40) return 'LIMITED';
    return 'STOP';
  }
  
  /// Determine overall confidence from components
  String _determineConfidence(List<String> confidences) {
    final lowCount = confidences.where((c) => c == 'low').length;
    final highCount = confidences.where((c) => c == 'high').length;
    
    if (highCount > confidences.length / 2) return 'high';
    if (lowCount > 0) return 'low';
    return 'medium';
  }
}
