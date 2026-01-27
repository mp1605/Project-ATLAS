import '../database/secure_database_manager.dart';
import 'dart:math';
import '../models/readiness/sleep_score.dart';
import '../services/sleep_source_resolver.dart';

/// Calculates sleep quality score (E2) using 4 components
/// 
/// Components:
/// 1. Duration adequacy (40% weight)
/// 2. Stage ratio - Deep + REM (30% weight)
/// 3. Fragmentation - wake time (20% weight)
/// 4. Regularity - consistent timing (10% weight)
/// 
/// Supports both auto (Apple Watch) and manual sleep entries
class SleepScoreCalculator {
  /// Target sleep duration in hours
  static const double targetSleepHours = 7.5;
  
  /// Duration sensitivity (sigmoid steepness)
  static const double durationSensitivity = 0.75;
  
  /// Target stage ratio (deep + REM should be >35% of total)
  static const double targetStageRatio = 0.35;
  static const double stageRatioRange = 0.20;
  
  /// Target fragmentation (awake time should be <8%)
  static const double targetFragmentation = 0.08;
  static const double fragmentationRange = 0.12;
  
  /// Maximum regularity penalty (hours of deviation)
  static const double maxRegularityPenalty = 2.0;

  /// Calculate sleep score for a given date
  /// 
  /// Uses SleepSourceResolver to get the best available sleep data
  /// (auto from Apple Watch, or manual entry from user)
  static Future<SleepScore?> calculate({
    required String userEmail,
    required DateTime date,
  }) async {
    // Format date for SleepSourceResolver (YYYY-MM-DD)
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // Resolve sleep source (auto vs manual)
    final resolvedSleep = await SleepSourceResolver.getSleepForDate(userEmail, dateStr);
    
    if (resolvedSleep.isMissing) {
      print('⚠️ No sleep data for $date (source: ${resolvedSleep.source})');
      return null;
    }

    final totalSleepMinutes = resolvedSleep.minutes.toDouble();
    final totalSleepHours = totalSleepMinutes / 60.0;

    // Component 1: Duration adequacy (sigmoid) - works for both auto and manual
    final d = _sigmoid((totalSleepHours - targetSleepHours) / durationSensitivity);

    double s, f, regularityScore;

    if (resolvedSleep.source == 'manual' && resolvedSleep.manualSleepData != null) {
      // === MANUAL SLEEP: Use quality ratings ===
      final manual = resolvedSleep.manualSleepData!;
      
      // Stage component from sleep quality rating (1-5 → 0-1)
      final qualityRating = manual.sleepQuality1to5 ?? 3;
      s = (qualityRating - 1) / 4.0; // Maps 1-5 to 0-1
      
      // Fragmentation from wake frequency (0=none, 3=many → invert to 0-1)
      final wakeFreq = manual.wakeFrequency ?? 1;
      f = 1 - (wakeFreq / 3.0); // Maps 0-3 to 1-0
      
      // Regularity from rested feeling (1-5 → 0-1)
      final restedRating = manual.restedFeeling1to5 ?? 3;
      regularityScore = (restedRating - 1) / 4.0; // Maps 1-5 to 0-1
      
      print('📝 Using MANUAL sleep: ${totalSleepHours.toStringAsFixed(1)}h, quality=$qualityRating, wakeFreq=$wakeFreq');
      
    } else {
      // === AUTO SLEEP: Use actual stage data ===
      final stageData = await _getAutoSleepStages(userEmail, date);
      
      if (stageData != null) {
        final deepMinutes = stageData['deep'] ?? 0.0;
        final remMinutes = stageData['rem'] ?? 0.0;
        final awakeMinutes = stageData['awake'] ?? 0.0;
        
        // Component 2: Stages (deep + REM ratio)
        final stageRatio = (deepMinutes + remMinutes) / totalSleepMinutes;
        s = _clip((stageRatio - targetStageRatio) / stageRatioRange, 0, 1);
        
        // Component 3: Fragmentation (lower is better, inverted)
        final fragmentation = awakeMinutes / totalSleepMinutes;
        f = 1 - _clip((fragmentation - targetFragmentation) / fragmentationRange, 0, 1);
      } else {
        // No stage data - use neutral values
        s = 0.5;
        f = 0.5;
      }
      
      // Component 4: Regularity
      final sleepMidpoint = resolvedSleep.sleepStart != null && resolvedSleep.sleepEnd != null
          ? resolvedSleep.sleepStart!.add(Duration(minutes: (totalSleepMinutes / 2).round()))
          : DateTime(date.year, date.month, date.day, 2, 30); // Default to 2:30 AM
          
      regularityScore = await _calculateRegularity(
        userEmail: userEmail,
        sleepMidpoint: sleepMidpoint,
      );
      
      print('🍎 Using AUTO sleep: ${totalSleepHours.toStringAsFixed(1)}h');
    }

    // Combined score (weighted)
    final totalScore = 100 * (0.40 * d + 0.30 * s + 0.20 * f + 0.10 * regularityScore);

    final score = SleepScore(
      totalScore: totalScore,
      duration: d * 100,
      stages: s * 100,
      fragmentation: f * 100,
      regularity: regularityScore * 100,
      totalSleepHours: totalSleepHours,
      deepMinutes: 0, // TODO: populate from stage data if available
      remMinutes: 0,
      awakeMinutes: 0,
      sleepMidpoint: DateTime(date.year, date.month, date.day, 2, 30),
      source: resolvedSleep.source,
    );

    print('✅ Sleep score for $date: ${totalScore.toStringAsFixed(1)} (source: ${resolvedSleep.source})');
    return score;
  }

  /// Get auto sleep stage data from database
  static Future<Map<String, double>?> _getAutoSleepStages(String userEmail, DateTime date) async {
    final sleepStart = DateTime(date.year, date.month, date.day, 20, 0); // 8 PM
    final sleepEnd = sleepStart.add(Duration(hours: 14)); // Next day 10 AM

    final db = await SecureDatabaseManager.instance.database;
    
    final sleepMetrics = await db.query(
      'health_metrics',
      where: 'user_email = ? AND timestamp >= ? AND timestamp <= ? AND '
             '(metric_type = ? OR metric_type = ? OR metric_type = ?)',
      whereArgs: [
        userEmail,
        sleepStart.millisecondsSinceEpoch,
        sleepEnd.millisecondsSinceEpoch,
        'SLEEP_DEEP',
        'SLEEP_REM',
        'SLEEP_AWAKE',
      ],
    );

    if (sleepMetrics.isEmpty) return null;

    double deepMinutes = 0;
    double remMinutes = 0;
    double awakeMinutes = 0;

    for (var metric in sleepMetrics) {
      final type = metric['metric_type'] as String;
      final value = (metric['value'] as num).toDouble();
      
      switch (type) {
        case 'SLEEP_DEEP':
          deepMinutes += value;
          break;
        case 'SLEEP_REM':
          remMinutes += value;
          break;
        case 'SLEEP_AWAKE':
          awakeMinutes += value;
          break;
      }
    }

    return {
      'deep': deepMinutes,
      'rem': remMinutes,
      'awake': awakeMinutes,
    };
  }

  /// Calculate regularity component (0-1)
  /// 
  /// Penalizes deviation from median sleep midpoint time
  static Future<double> _calculateRegularity({
    required String userEmail,
    required DateTime sleepMidpoint,
  }) async {
    // Get last 28 days of sleep midpoints
    final end = DateTime.now();
    final start = end.subtract(Duration(days: 28));

    // For now, return neutral score (0.5) since we don't have historical midpoints stored
    // TODO: Store sleep start/end times and compute actual midpoint baselines
    
    // Simplified: assume regularity is based on how close midpoint is to ideal (2-3 AM)
    final idealMidpoint = DateTime(
      sleepMidpoint.year,
      sleepMidpoint.month,
      sleepMidpoint.day,
      2, 30, // 2:30 AM ideal
    );

    final deviationHours = (sleepMidpoint.difference(idealMidpoint).inMinutes / 60.0).abs();
    final penalty = min(maxRegularityPenalty, deviationHours);
    
    final regularityScore = 1 - (penalty / maxRegularityPenalty);
    
    return regularityScore;
  }

  /// Sigmoid function σ(x) = 1 / (1 + e^(-x))
  static double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  /// Clip value to [min, max] range
  static double _clip(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
