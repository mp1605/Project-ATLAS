import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../foundation/baseline_calculator_v2.dart';
import '../../models/user_profile.dart';
import '../safety_scores/all_safety_scores.dart';
import '../../services/last_sleep_service.dart';
import '../../services/sleep_source_resolver.dart';

/// Score #13: Altitude/Oxygenation (0-100)
class AltitudeScoreCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  AltitudeScoreCalculator({required this.db, required this.baseline});
  
  Future<Map<String, dynamic>> calculate({required String userEmail, required DateTime date}) async {
    final spo2Value = await _getValue(userEmail, 'BLOOD_OXYGEN', date);
    final ppiValue = await _getValue(userEmail, 'PERIPHERAL_PERFUSION_INDEX', date);
    final rrValue = await _getValue(userEmail, 'RESPIRATORY_RATE', date);
    
    final spo2Base = await baseline.calculate(userEmail: userEmail, metricType: 'BLOOD_OXYGEN', endDate: date);
    final ppiBase = await baseline.calculate(userEmail: userEmail, metricType: 'PERIPHERAL_PERFUSION_INDEX', endDate: date);
    final rrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESPIRATORY_RATE', endDate: date);
    
    final o2Drop = math.max(0, -baseline.computeZScore(spo2Value, spo2Base));
    final perfDrop = math.max(0, -baseline.computeZScore(ppiValue, ppiBase));
    final rrRise = math.max(0, baseline.computeZScore(rrValue, rrBase));
    
    final altitudeRisk = 0.5 * o2Drop + 0.3 * perfDrop + 0.2 * rrRise;
    final score = (85 - 30 * altitudeRisk).clamp(0, 100);
    
    return {
      'score': score.toDouble(), 
      'confidence': 'medium',
      'components': {
        'spo2': spo2Value,
        'ppi': ppiValue,
        'resp_rate': rrValue,
        'o2_drop_z': o2Drop,
      }
    };
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }
}

/// Score #14: Cardiac Safety Penalty (0-100)
class CardiacSafetyCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  CardiacSafetyCalculator({required this.db, required this.baseline});
  
  Future<Map<String, dynamic>> calculate({required String userEmail, required DateTime date}) async {
    final start = date.subtract(Duration(hours: 24));
    
    final highEvents = await _countEvents(userEmail, 'HIGH_HEART_RATE_EVENT', start, date);
    final lowEvents = await _countEvents(userEmail, 'LOW_HEART_RATE_EVENT', start, date);
    final irregEvents = await _countEvents(userEmail, 'IRREGULAR_HEART_RATE_EVENT', start, date);
    
    final eventCount = highEvents + lowEvents + 2 * irregEvents;
    
    final rhrValue = await _getValue(userEmail, 'RESTING_HEART_RATE', date);
    final rhrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESTING_HEART_RATE', endDate: date);
    final zRHR = baseline.computeZScore(rhrValue, rhrBase);
    
    var penalty = (20 * math.min(5, eventCount) + 10 * math.max(0, zRHR)).toDouble().clamp(0, 100);
    
    return {
      'score': penalty.toDouble(), 
      'confidence': 'high',
      'components': {
        'high_hr_events': highEvents,
        'low_hr_events': lowEvents,
        'irregular_events': irregEvents,
        'resting_hr_z': zRHR,
      }
    };
  }
  
  Future<int> _countEvents(String userEmail, String type, DateTime start, DateTime end) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp <= ?',
        whereArgs: [userEmail, type, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
    return r.length;
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }
}

/// Score #15: Sleep Debt (0-100)
class SleepDebtCalculator {
  final Database db;
  
  SleepDebtCalculator(this.db);
  
  Future<Map<String, dynamic>> calculate({
    required String userEmail,
    required DateTime date,
    required int targetSleep,
  }) async {
    final debt7 = await _calculateDebt(userEmail, date, 7, targetSleep);
    final score = (100 - 100 * math.min(1.0, debt7 / (7 * 90))).clamp(0, 100);
    
    return {
      'score': score.toDouble(), 
      'confidence': 'high',
      'components': {
        'total_debt_7d_min': debt7,
        'target_sleep_min': targetSleep.toDouble(),
      }
    };
  }
  
  Future<double> _calculateDebt(String userEmail, DateTime date, int days, int target) async {
    var totalDebt = 0.0;
    for (var i = 0; i < days; i++) {
      final checkDate = date.subtract(Duration(days: i));
      final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      
      // Use resolver to get manual or auto sleep for each day
      final resolved = await SleepSourceResolver.getSleepForDate(userEmail, dateStr);
      final asleep = resolved.minutes.toDouble();
      
      totalDebt += math.max(0, target - asleep);
    }
    return totalDebt;
  }
  
  Future<double> _getSum(String userEmail, String type, DateTime start, DateTime end) async {
    final r = await db.rawQuery('''
      SELECT SUM(value) as total 
      FROM health_metrics 
      WHERE user_email = ? AND metric_type = ? 
      AND timestamp >= ? AND timestamp <= ?
    ''', [userEmail, type, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
    
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }
}

/// Score #16: Training Readiness (0-100)
class TrainingReadinessCalculator {
  Future<Map<String, dynamic>> calculate({
    required double recoveryScore,
    required double sleepScore,
    required double fatigueScore,
    required double injuryRisk,
  }) async {
    final score = (0.40 * recoveryScore + 
                  0.25 * sleepScore + 
                  0.20 * (100 - fatigueScore) + 
                  0.15 * (100 - injuryRisk)).clamp(0, 100);
    
    String category;
    if (score >= 75) {
      category = 'GREEN';
    } else if (score >= 55) {
      category = 'AMBER';
    } else {
      category = 'RED';
    }
    
    return {'score': score, 'category': category, 'confidence': 'high'};
  }
}

/// Score #17: Cognitive Alertness (0-100)
class CognitiveAlertnessCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  CognitiveAlertnessCalculator({required this.db, required this.baseline});
  
  Future<Map<String, dynamic>> calculate({required String userEmail, required DateTime date}) async {
    // Get resolved sleep (manual or auto) for total sleep duration
    final dateStr = SleepSourceResolver.getTodayWakeDate();
    final resolved = await SleepSourceResolver.getSleepForDate(userEmail, dateStr);
    final asleepValue = resolved.minutes.toDouble();
    
    // Get auto sleep for sleep stages (fallback to 0 for manual)
    final lastSleep = await LastSleepService.getLastSleep(userEmail);
    final remValue = lastSleep?.remMinutes.toDouble() ?? 0.0;
    final awakeValue = lastSleep?.awakeMinutes.toDouble() ?? 0.0;
    
    // Core physiological snapshots (latest is correct here for 'state')
    final hrvValue = await _getValue(userEmail, 'HRV_RMSSD', date);
    final edaValue = await _getValue(userEmail, 'ELECTRODERMAL_ACTIVITY', date);
    
    // Mindfulness is a 24-hour total
    final startSum = date.subtract(const Duration(hours: 24));
    final mindfulness = await _getSum(userEmail, 'MINDFULNESS', startSum, date);
    
    final remScore = (100 * math.min(1.0, (remValue / (asleepValue + 0.001)) / 0.22)).clamp(0, 100);
    final fragment = (100 - 100 * math.min(1.0, (awakeValue / (asleepValue + 0.001) - 0.05) / 0.10)).clamp(0, 100);
    
    final hrvBase = await baseline.calculate(userEmail: userEmail, metricType: 'HRV_RMSSD', endDate: date);
    final edaBase = await baseline.calculate(userEmail: userEmail, metricType: 'ELECTRODERMAL_ACTIVITY', endDate: date);
    
    final zHRV = baseline.computeZScore(hrvValue, hrvBase);
    final zEDA = edaValue > 0 ? baseline.computeZScore(edaValue, edaBase) : 0.0;
    
    // Autonomic balance from both HRV and EDA
    final autonomic = (50 + 12.5 * zHRV - 12.5 * math.max(0, zEDA)).clamp(0, 100);
    final mind = math.min(1.0, mindfulness / 10);
    
    final score = (0.35 * remScore + 0.25 * fragment + 0.30 * autonomic + 10 * mind).clamp(0, 100);
    
    return {
      'score': score.toDouble(), 
      'confidence': 'high',
      'components': {
        'rem_score': remScore.toDouble(),
        'fragmentation': fragment.toDouble(),
        'autonomic': autonomic.toDouble(),
        'mindfulness_min': mindfulness.toDouble(),
        'eda_z': zEDA.toDouble(),
      }
    };
  }
  
  Future<double> _getSum(String userEmail, String type, DateTime start, DateTime end) async {
    final r = await db.rawQuery('''
      SELECT SUM(value) as total 
      FROM health_metrics 
      WHERE user_email = ? AND metric_type = ? 
      AND timestamp >= ? AND timestamp <= ?
    ''', [userEmail, type, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
    
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }
}

/// Score #18: Thermoregulatory Adaptation (0-100)
class ThermoregulatoryAdaptationCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  ThermoregulatoryAdaptationCalculator({required this.db, required this.baseline});
  
  Future<Map<String, dynamic>> calculate({required String userEmail, required DateTime date}) async {
    final tempValue = await _getValue(userEmail, 'BODY_TEMPERATURE', date);
    final rhrValue = await _getValue(userEmail, 'RESTING_HEART_RATE', date);
    final rrValue = await _getValue(userEmail, 'RESPIRATORY_RATE', date);
    
    final tempBase = await baseline.calculate(userEmail: userEmail, metricType: 'BODY_TEMPERATURE', endDate: date);
    final rhrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESTING_HEART_RATE', endDate: date);
    final rrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESPIRATORY_RATE', endDate: date);
    
    final tempDelta = baseline.computeZScore(tempValue, tempBase);
    final coupledStrain = math.max(0, baseline.computeZScore(rhrValue, rhrBase)) + 
                         math.max(0, baseline.computeZScore(rrValue, rrBase)) + 
                         math.max(0, tempDelta);
    
    final energy7d = await _getWeeklyAvg(userEmail, 'ACTIVE_ENERGY_BURNED', date);
    final energyPercentile = (energy7d / 10).clamp(0, 100);
    
    final score = (80 - 20 * coupledStrain + 0.2 * energyPercentile).clamp(0, 100);
    
    return {'score': score, 'confidence': 'medium'};
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }
  
  Future<double> _getWeeklyAvg(String userEmail, String type, DateTime date) async {
    final start = date.subtract(Duration(days: 7));
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp <= ?',
        whereArgs: [userEmail, type, start.millisecondsSinceEpoch, date.millisecondsSinceEpoch]);
    if (r.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (var row in r) {
      sum += (row['value'] as num).toDouble();
    }
    return sum / r.length;
  }
}

/// Aggregator for all specialty scores (13-18)
class AllSpecialtyScoresCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  AllSpecialtyScoresCalculator({required this.db}) : baseline = BaselineCalculatorV2(db);
  
  Future<ScoreResult> calculateAltitudeScore({required String userEmail, required DateTime date}) async {
    final calc = AltitudeScoreCalculator(db: db, baseline: baseline);
    final res = await calc.calculate(userEmail: userEmail, date: date);
    return ScoreResult(score: res['score'], confidence: res['confidence'], components: res['components'] ?? {});
  }
  
  Future<ScoreResult> calculateCardiacSafetyPenalty({required String userEmail, required DateTime date}) async {
    final calc = CardiacSafetyCalculator(db: db, baseline: baseline);
    final res = await calc.calculate(userEmail: userEmail, date: date);
    return ScoreResult(score: res['score'], confidence: res['confidence'], components: res['components'] ?? {});
  }
  
  Future<ScoreResult> calculateSleepDebt({
    required String userEmail,
    required DateTime date,
    required UserProfile profile,
  }) async {
    final calc = SleepDebtCalculator(db);
    final res = await calc.calculate(
      userEmail: userEmail,
      date: date,
      targetSleep: profile.targetSleep, // Use minutes directly
    );
    return ScoreResult(score: res['score'], confidence: res['confidence'], components: res['components'] ?? {});
  }
  
  Future<ScoreResult> calculateTrainingReadiness({
    required String userEmail,
    required DateTime date,
    required double recoveryScore,
    required double sleepScore,
    required double fatigueScore,
    required double injuryRiskScore,
  }) async {
    final calc = TrainingReadinessCalculator();
    final res = await calc.calculate(
      recoveryScore: recoveryScore,
      sleepScore: sleepScore,
      fatigueScore: fatigueScore,
      injuryRisk: injuryRiskScore,
    );
    return ScoreResult(score: res['score'], confidence: res['confidence'], components: res['components'] ?? {});
  }
  
  Future<ScoreResult> calculateCognitiveAlertness({required String userEmail, required DateTime date}) async {
    final calc = CognitiveAlertnessCalculator(db: db, baseline: baseline);
    final res = await calc.calculate(userEmail: userEmail, date: date);
    return ScoreResult(score: res['score'], confidence: res['confidence'], components: res['components'] ?? {});
  }
  
  Future<ScoreResult> calculateThermoregulatoryAdaptation({required String userEmail, required DateTime date}) async {
    final calc = ThermoregulatoryAdaptationCalculator(db: db, baseline: baseline);
    final res = await calc.calculate(userEmail: userEmail, date: date);
    return ScoreResult(score: res['score'], confidence: res['confidence'], components: res['components'] ?? {});
  }
}

class ScoreResult {
  final double score;
  final String confidence;
  final Map<String, dynamic> components;
  ScoreResult({required this.score, required this.confidence, this.components = const {}});
}
