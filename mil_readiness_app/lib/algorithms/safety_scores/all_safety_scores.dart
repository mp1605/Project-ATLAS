import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../foundation/baseline_calculator_v2.dart';
import '../../models/user_profile.dart';

/// Score #7: Stress Load (0-100) - higher = more stress
class StressLoadCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  StressLoadCalculator({required this.db, required this.baseline});
  
  Future<Map<String, dynamic>> calculate({
    required String userEmail,
    required DateTime date,
  }) async {
    final edaValue = await _getValue(userEmail, 'ELECTRODERMAL_ACTIVITY', date);
    final hrValue = await _getValue(userEmail, 'HEART_RATE', date);
    final hrvValue = await _getValue(userEmail, 'HRV_RMSSD', date);
    final mindfulness = await _getDailySum(userEmail, 'MINDFULNESS', date);
    
    final edaBase = await baseline.calculate(userEmail: userEmail, metricType: 'ELECTRODERMAL_ACTIVITY', endDate: date);
    final hrBase = await baseline.calculate(userEmail: userEmail, metricType: 'HEART_RATE', endDate: date);
    final hrvBase = await baseline.calculate(userEmail: userEmail, metricType: 'HRV_RMSSD', endDate: date);
    
    final zEDA = baseline.computeZScore(edaValue, edaBase);
    final zHR = baseline.computeZScore(hrValue, hrBase);
    final zHRV = baseline.computeZScore(hrvValue, hrvBase);
    
    final stressRaw = 0.5 * math.max(0, zEDA) + 0.3 * math.max(0, zHR) + 0.2 * math.max(0, -zHRV);
    final mind = math.min(1.0, mindfulness / 10.0);
    final score = (50 + 25 * stressRaw - 10 * mind).clamp(0.0, 100.0);
    
    return {'score': score, 'confidence': edaValue > 0 ? 'medium' : 'low'};
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }

  Future<double> _getDailySum(String userEmail, String type, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final nextDay = startOfDay.add(const Duration(days: 1));
    
    final r = await db.rawQuery('''
      SELECT SUM(value) as total 
      FROM health_metrics 
      WHERE user_email = ? AND metric_type = ? 
      AND timestamp >= ? AND timestamp < ?
    ''', [
      userEmail, 
      type, 
      startOfDay.millisecondsSinceEpoch, 
      nextDay.millisecondsSinceEpoch
    ]);
    
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}

/// Score #8: Injury Risk Indicator (0-100)
class InjuryRiskCalculator {
  final Database db;
  
  InjuryRiskCalculator(this.db);
  
  Future<Map<String, dynamic>> calculate({
    required String userEmail,
    required DateTime date,
    required double acwr,
    required double fatigueScore,
    required double sleepAsleep,
    required int targetSleep,
  }) async {
    final spike = acwr.clamp(0, 2);
    final steps7d = await _getWeeklySum(userEmail, 'STEPS', date);
    final flights7d = await _getWeeklySum(userEmail, 'FLIGHTS_CLIMBED', date);
    final impactVolume = ((steps7d + 120 * flights7d) / 100000 * 100).clamp(0, 100);
    final sleepDebt = math.max(0, (targetSleep - sleepAsleep) / targetSleep);
    
    final u = (spike - 1.2) / 0.1;
    final sigmoid = 1 / (1 + math.exp(-u));
    final risk = (40 * sigmoid + 30 * (fatigueScore / 100) + 20 * sleepDebt + 10 * (impactVolume / 100)).clamp(0, 100);
    
    return {'score': risk, 'confidence': 'medium'};
  }
  
  Future<double> _getWeeklySum(String userEmail, String type, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day).subtract(const Duration(days: 7));
    final r = await db.rawQuery('''
      SELECT SUM(value) as total 
      FROM health_metrics 
      WHERE user_email = ? AND metric_type = ? 
      AND timestamp >= ? AND timestamp <= ?
    ''', [userEmail, type, start.millisecondsSinceEpoch, date.millisecondsSinceEpoch]);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}

/// Score #9: Cardio-Respiratory Stability (0-100)
class CardioRespStabilityCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  CardioRespStabilityCalculator({required this.db, required this.baseline});
  
  Future<Map<String, dynamic>> calculate({required String userEmail, required DateTime date}) async {
    final rrValue = await _getValue(userEmail, 'RESPIRATORY_RATE', date);
    final spo2Value = await _getValue(userEmail, 'BLOOD_OXYGEN', date);
    final ppiValue = await _getValue(userEmail, 'PERIPHERAL_PERFUSION_INDEX', date);
    final rhrValue = await _getValue(userEmail, 'RESTING_HEART_RATE', date);
    final tempValue = await _getValue(userEmail, 'BODY_TEMPERATURE', date);
    
    final rrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESPIRATORY_RATE', endDate: date);
    final spo2Base = await baseline.calculate(userEmail: userEmail, metricType: 'BLOOD_OXYGEN', endDate: date);
    final ppiBase = await baseline.calculate(userEmail: userEmail, metricType: 'PERIPHERAL_PERFUSION_INDEX', endDate: date);
    final rhrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESTING_HEART_RATE', endDate: date);
    final tempBase = await baseline.calculate(userEmail: userEmail, metricType: 'BODY_TEMPERATURE', endDate: date);
    
    final zRR = baseline.computeZScore(rrValue, rrBase);
    final zSpO2 = baseline.computeZScore(spo2Value, spo2Base);
    final zPPI = baseline.computeZScore(ppiValue, ppiBase);
    final zRHR = baseline.computeZScore(rhrValue, rhrBase);
    final zTemp = baseline.computeZScore(tempValue, tempBase);
    
    final rrScore = (50 - 15 * zRR).clamp(0, 100);
    final spo2Score = (50 + 20 * zSpO2).clamp(0, 100);
    final ppiScore = (50 + 10 * zPPI).clamp(0, 100);
    final hrTempPen = 10 * math.max(0, zRHR) + 10 * zTemp.abs();
    
    final score = (0.25 * rrScore + 0.35 * spo2Score + 0.20 * ppiScore + 0.20 * (100 - hrTempPen)).clamp(0, 100);
    return {'score': score, 'confidence': 'high'};
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }
}

/// Score #10: Heat/Illness Risk Flag (0-100)
class IllnessRiskCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  IllnessRiskCalculator({required this.db, required this.baseline});
  
  Future<Map<String, dynamic>> calculate({
    required String userEmail,
    required DateTime date,
    required double sleepAsleep,
    required int targetSleep,
  }) async {
    final tempValue = await _getValue(userEmail, 'BODY_TEMPERATURE', date);
    final rhrValue = await _getValue(userEmail, 'RESTING_HEART_RATE', date);
    final rrValue = await _getValue(userEmail, 'RESPIRATORY_RATE', date);
    final hrvValue = await _getValue(userEmail, 'HRV_RMSSD', date);
    
    final tempBase = await baseline.calculate(userEmail: userEmail, metricType: 'BODY_TEMPERATURE', endDate: date);
    final rhrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESTING_HEART_RATE', endDate: date);
    final rrBase = await baseline.calculate(userEmail: userEmail, metricType: 'RESPIRATORY_RATE', endDate: date);
    final hrvBase = await baseline.calculate(userEmail: userEmail, metricType: 'HRV_RMSSD', endDate: date);
    
    final tempDev = baseline.computeZScore(tempValue, tempBase).abs();
    final rhrUp = math.max(0, baseline.computeZScore(rhrValue, rhrBase));
    final rrUp = math.max(0, baseline.computeZScore(rrValue, rrBase));
    final hrvDown = math.max(0, -baseline.computeZScore(hrvValue, hrvBase));
    
    final illnessRaw = 0.40 * tempDev + 0.25 * rhrUp + 0.20 * rrUp + 0.15 * hrvDown;
    final sleepPenalty = math.max(0, (targetSleep - sleepAsleep) / targetSleep);
    final risk = (30 + 35 * illnessRaw + 20 * sleepPenalty).clamp(0, 100);
    
    return {
      'score': risk.toDouble(), 
      'confidence': 'high',
      'components': {
        'body_temp_c': tempValue.toDouble(),
        'resting_hr': rhrValue.toDouble(),
        'resp_rate': rrValue.toDouble(),
        'hrv_rmssd': hrvValue.toDouble(),
        'temp_z': tempDev.toDouble(),
      }
    };
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }
}

/// Score #11: Daily Activity (0-100)
class DailyActivityCalculator {
  final Database db;
  
  DailyActivityCalculator(this.db);
  
  Future<Map<String, dynamic>> calculate({required String userEmail, required DateTime date}) async {
    final steps = await _getDailySum(userEmail, 'STEPS', date);
    final distance = await _getDailySum(userEmail, 'DISTANCE_WALKING_RUNNING', date);
    final floors = await _getDailySum(userEmail, 'FLIGHTS_CLIMBED', date);
    final energy = await _getDailySum(userEmail, 'ACTIVE_ENERGY_BURNED', date);
    
    final stepsScore = (100 * math.min(1.0, steps / 10000.0)).clamp(0.0, 100.0);
    final distScore = (100 * math.min(1.0, distance / 8000.0)).clamp(0.0, 100.0);
    final floorsScore = (100 * math.min(1.0, floors / 20.0)).clamp(0.0, 100.0);
    final energyScore = (100 * math.min(1.0, energy / 600.0)).clamp(0.0, 100.0);
    
    final score = (0.35 * stepsScore + 0.25 * distScore + 0.15 * floorsScore + 0.25 * energyScore);
    return {
      'score': score.toDouble(), 
      'confidence': 'high',
      'components': {
        'steps': steps.toDouble(),
        'distance_m': distance.toDouble(),
        'floors': floors.toDouble(),
        'energy_kcal': energy.toDouble(),
        'step_score': stepsScore.toDouble(),
      }
    };
  }
  
  Future<double> _getValue(String userEmail, String type, DateTime date) async {
    final r = await db.query('health_metrics', where: 'user_email = ? AND metric_type = ? AND timestamp <= ?',
        whereArgs: [userEmail, type, date.millisecondsSinceEpoch], orderBy: 'timestamp DESC', limit: 1);
    return r.isEmpty ? 0.0 : (r.first['value'] as num).toDouble();
  }

  Future<double> _getDailySum(String userEmail, String type, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final nextDay = startOfDay.add(const Duration(days: 1));
    
    final r = await db.rawQuery('''
      SELECT SUM(value) as total 
      FROM health_metrics 
      WHERE user_email = ? AND metric_type = ? 
      AND timestamp >= ? AND timestamp < ?
    ''', [
      userEmail, 
      type, 
      startOfDay.millisecondsSinceEpoch, 
      nextDay.millisecondsSinceEpoch
    ]);
    
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}


/// Aggregator for all safety scores (7-12)
class AllSafetyScoresCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  
  AllSafetyScoresCalculator({required this.db}) : baseline = BaselineCalculatorV2(db);
  
  Future<ScoreResult> calculateStressLoad({required String userEmail, required DateTime date}) async {
    final calc = StressLoadCalculator(db: db, baseline: baseline);
    final res = await calc.calculate(userEmail: userEmail, date: date);
    return ScoreResult(
      score: (res['score'] as num).toDouble(), 
      confidence: (res['confidence'] as String), 
      components: (res['components'] as Map<String, dynamic>?) ?? {}
    );
  }
  
  Future<ScoreResult> calculateInjuryRisk({
    required String userEmail,
    required DateTime date,
    required double fatigueScore,
    required UserProfile profile,
  }) async {
    final calc = InjuryRiskCalculator(db);
    // Note: This relies on ACWR and Sleep which are simplified here for now
    final res = await calc.calculate(
      userEmail: userEmail,
      date: date,
      acwr: 1.0, 
      fatigueScore: fatigueScore,
      sleepAsleep: 420.0,
      targetSleep: profile.targetSleep ?? 480,
    );
    return ScoreResult(
      score: (res['score'] as num).toDouble(), 
      confidence: (res['confidence'] as String), 
      components: (res['components'] as Map<String, dynamic>?) ?? {}
    );
  }
  
  Future<ScoreResult> calculateCardioRespStability({required String userEmail, required DateTime date}) async {
    final calc = CardioRespStabilityCalculator(db: db, baseline: baseline);
    final res = await calc.calculate(userEmail: userEmail, date: date);
    return ScoreResult(
      score: (res['score'] as num).toDouble(), 
      confidence: (res['confidence'] as String), 
      components: (res['components'] as Map<String, dynamic>?) ?? {}
    );
  }
  
  Future<ScoreResult> calculateIllnessRisk({
    required String userEmail,
    required DateTime date,
    required UserProfile profile,
  }) async {
    final calc = IllnessRiskCalculator(db: db, baseline: baseline);
    final res = await calc.calculate(
      userEmail: userEmail,
      date: date,
      sleepAsleep: 420.0,
      targetSleep: profile.targetSleep ?? 480,
    );
    return ScoreResult(
      score: (res['score'] as num).toDouble(), 
      confidence: (res['confidence'] as String), 
      components: (res['components'] as Map<String, dynamic>?) ?? {}
    );
  }
  
  Future<ScoreResult> calculateDailyActivity({required String userEmail, required DateTime date}) async {
    final calc = DailyActivityCalculator(db);
    final res = await calc.calculate(userEmail: userEmail, date: date);
    return ScoreResult(
      score: (res['score'] as num).toDouble(), 
      confidence: (res['confidence'] as String), 
      components: (res['components'] as Map<String, dynamic>?) ?? {}
    );
  }
  
  Future<ScoreResult> calculateWorkCapacity({
    required String userEmail,
    required DateTime date,
    required double recoveryScore,
    required double sleepScore,
  }) async {
    final calc = WorkCapacityCalculator(db);
    final res = await calc.calculate(recoveryScore: recoveryScore, sleepScore: sleepScore);
    return ScoreResult(
      score: (res['score'] as num).toDouble(), 
      confidence: (res['confidence'] as String), 
      components: (res['components'] as Map<String, dynamic>?) ?? {}
    );
  }
}

class ScoreResult {
  final double score;
  final String confidence;
  final Map<String, dynamic> components;
  ScoreResult({required this.score, required this.confidence, this.components = const {}});
}

/// Score #12: Work Capacity (0-100)
class WorkCapacityCalculator {
  final Database db;
  
  WorkCapacityCalculator(this.db);
  
  Future<Map<String, dynamic>> calculate({
    required double recoveryScore,
    required double sleepScore,
  }) async {
    final capacityBase = 0.5 * recoveryScore + 0.5 * sleepScore;
    final score = capacityBase.clamp(0, 100);
    return {
      'score': score.toDouble(), 
      'confidence': 'high',
      'components': {
        'recovery_factor': recoveryScore,
        'sleep_factor': sleepScore,
      }
    };
  }
}
