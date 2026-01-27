import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/user_profile.dart';
import '../../models/manual_activity_entry.dart';
import '../../repositories/manual_activity_repository.dart';
import '../foundation/baseline_calculator_v2.dart';
import '../foundation/ewma_calculator.dart';
import '../foundation/acwr_calculator.dart';
import '../foundation/trimp_calculator.dart';

/// Fatigue Index Result
class FatigueIndexResult {
  final double score; // 0-100 (higher = more fatigued)
  final double acwr;
  final double acuteLoad;
  final double chronicLoad;
  final String riskCategory;
  final String confidence;
  final Map<String, dynamic> components;
  
  const FatigueIndexResult({
    required this.score,
    required this.acwr,
    required this.acuteLoad,
    required this.chronicLoad,
    required this.riskCategory,
    required this.confidence,
    required this.components,
  });
}

/// Score #3: Fatigue Index (0-100)
/// Training load and recovery suppression
class FatigueIndexCalculator {
  final Database db;
  final BaselineCalculatorV2 baseline;
  final EWMACalculator ewma;
  final ACWRCalculator acwr;
  final TRIMPCalculator trimp;
  
  FatigueIndexCalculator({
    required this.db,
    required this.baseline,
    required this.ewma,
    required this.acwr,
    required this.trimp,
  });
  
  /// Calculate fatigue index for a given date
  Future<FatigueIndexResult> calculate({
    required String userEmail,
    required DateTime date,
    required UserProfile profile,
  }) async {
    // Get ACWR (Acute:Chronic Workload Ratio)
    final acwrResult = await acwr.calculate(userEmail, 'trimp');
    
    // Convert ACWR to load score using sigmoid
    final u = (acwrResult.acwr - 1.0) / 0.15;
    final sigmoid = 1 / (1 + math.exp(-u));
    final loadScore = (100 * sigmoid).clamp(0, 100);
    
    // Calculate recovery suppression
    final suppression = await _calculateSuppression(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    
    // Final fatigue = 60% load + 40% suppression
    final fatigueScore = (0.6 * loadScore + 0.4 * math.min(100, suppression))
        .clamp(0, 100);
    
    return FatigueIndexResult(
      score: fatigueScore.toDouble(),
      acwr: acwrResult.acwr,
      acuteLoad: acwrResult.acuteLoad,
      chronicLoad: acwrResult.chronicLoad,
      riskCategory: acwrResult.riskCategory,
      confidence: acwrResult.acuteLoad > 0 ? 'high' : 'medium',
      components: {
        'acwr': acwrResult.acwr,
        'acute_load': acwrResult.acuteLoad,
        'chronic_load': acwrResult.chronicLoad,
        'suppression': suppression.toDouble(),
      },
    );
  }
  
  /// Calculate TRIMP for a workout and update EWMA
  Future<void> processWorkout({
    required String userEmail,
    required int durationMinutes,
    required double avgHeartRate,
    required UserProfile profile,
  }) async {
    final trimpValue = trimp.calculate(
      durationMinutes: durationMinutes,
      avgHeartRate: avgHeartRate,
      restingHeartRate: await _getRestingHR(userEmail),
      maxHeartRate: profile.getHrMax().toDouble(),
      gender: profile.gender ?? 'other',
    );
    
    // Update 7-day EWMA (acute)
    await ewma.update7d(
      userEmail: userEmail,
      metricName: 'trimp',
      value: trimpValue,
    );
    
    // Update 28-day EWMA (chronic)
    await ewma.update28d(
      userEmail: userEmail,
      metricName: 'trimp',
      value: trimpValue,
    );
  }
  
  /// Calculate recovery suppression component
  Future<double> _calculateSuppression({
    required String userEmail,
    required DateTime date,
    required UserProfile profile,
  }) async {
    // Get HRV (RMSSD)
    final hrvValue = await _getLatestValue(userEmail, 'HRV_RMSSD', date);
    final hrvBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'HRV_RMSSD',
      endDate: date,
    );
    final zHRV = baseline.computeZScore(hrvValue, hrvBaseline);
    
    // Get RHR
    final rhrValue = await _getLatestValue(userEmail, 'RESTING_HEART_RATE', date);
    final rhrBaseline = await baseline.calculate(
      userEmail: userEmail,
      metricType: 'RESTING_HEART_RATE',
      endDate: date,
    );
    final zRHR = baseline.computeZScore(rhrValue, rhrBaseline);
    
    // Get sleep
    final sleepAsleep = await _getLatestValue(userEmail, 'SLEEP_ASLEEP', date);
    final targetSleep = profile.targetSleep.toDouble();
    final sleepDebt = math.max(0, (targetSleep - sleepAsleep) / targetSleep);
    
    // Suppression formula
    final suppression = 50 * math.max(0, -zHRV) +  // HRV suppression
                       30 * math.max(0, zRHR) +     // Elevated RHR
                       20 * sleepDebt;               // Sleep deficit
    
    return suppression.toDouble();
  }
  
  /// Get resting heart rate
  Future<double> _getRestingHR(String userEmail) async {
    final result = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ?',
      whereArgs: [userEmail, 'RESTING_HEART_RATE'],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    if (result.isEmpty) return 60.0; // Default
    return (result.first['value'] as num).toDouble();
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
  
  /// Calculate TRIMP from manual activity using RPE
  /// 
  /// Simplified TRIMP estimation:
  /// TRIMP_manual = duration_minutes * (RPE / 10) * 0.64
  /// 
  /// This approximates the Banister TRIMP using RPE as a proxy for heart rate intensity
  double _calculateManualTRIMP(ManualActivityEntry activity) {
    // RPE (1-10) maps to intensity (0.1-1.0)
    final intensity = activity.rpe / 10.0;
    
    // Simplified TRIMP: duration × intensity × base factor
    // Base factor 0.64 is the same as used in Banister TRIMP for males
    final trimp = activity.durationMinutes * intensity * 0.64;
    
    print('📝 Manual activity TRIMP: ${activity.activityType.name} (${activity.durationMinutes}min, RPE=${activity.rpe}) → TRIMP=$trimp');
    
    return trimp;
  }
  
  /// Get manual activities for a date and calculate their total TRIMP
  Future<double> _getManualActivitiesTRIMP(
    String userEmail,
    DateTime date,
  ) async {
    final repo = ManualActivityRepository();
    final activities = await repo.listForDay(
      userEmail: userEmail,
      dayLocal: date,
    );
    
    if (activities.isEmpty) {
      return 0.0;
    }
    
    double totalTRIMP = 0.0;
    for (final activity in activities) {
      totalTRIMP += _calculateManualTRIMP(activity);
    }
    
    print('📝 Total manual activity TRIMP for $date: $totalTRIMP (${activities.length} activities)');
    return totalTRIMP;
  }
  
  /// Process manual activity and update EWMA
  Future<void> processManualActivity({
    required String userEmail,
    required ManualActivityEntry activity,
  }) async {
    final trimpValue = _calculateManualTRIMP(activity);
    
    // Update 7-day EWMA (acute)
    await ewma.update7d(
      userEmail: userEmail,
      metricName: 'trimp',
      value: trimpValue,
    );
    
    // Update 28-day EWMA (chronic)
    await ewma.update28d(
      userEmail: userEmail,
      metricName: 'trimp',
      value: trimpValue,
    );
    
    print('✅ Processed manual activity: ${activity.activityType.name} → TRIMP=$trimpValue');
  }
}
