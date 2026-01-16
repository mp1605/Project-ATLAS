import '../database/secure_database_manager.dart';

import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/readiness/training_load.dart';

/// Calculates TRIMP (Training Impulse) from heart rate data (B5)
/// 
/// TRIMP = Σ (heart rate reserve ratio) for all workout minutes
/// where reserve ratio = (HR - HRrest) / (HRmax - HRrest)
class TrainingLoadCalculator {
  /// Default max HR formula: 220 - age
  static int estimateMaxHR(int age) => 220 - age;

  /// Calculate TRIMP for a specific date
  static Future<TrainingLoad?> calculate({
    required String userEmail,
    required DateTime date,
    int? userAge, // Optional, defaults to 30
  }) async {
    final age = userAge ?? 30;
    final maxHR = estimateMaxHR(age).toDouble();

    // Get resting HR from that day (or recent baseline)
    final restingHR = await _getRestingHR(userEmail, date);
    if (restingHR == null) {
      print('⚠️ No resting HR available for $date');
      return null;
    }

    // Get workout heart rate samples for the day
    final hrSamples = await _getWorkoutHeartRates(userEmail, date);
    if (hrSamples.isEmpty) {
      print('ℹ️ No workout data for $date');
      return TrainingLoad(
        trimp: 0,
        workoutMinutes: 0,
        averageHeartRate: restingHR,
        maxHeartRateUsed: maxHR,
        restingHeartRate: restingHR,
      );
    }

    // Calculate TRIMP (sum of reserve ratios)
    double trimp = 0;
    double totalHR = 0;

    for (var hr in hrSamples) {
      // Reserve ratio: (HR - HRrest) / (HRmax - HRrest)
      final reserve = (hr - restingHR) / (maxHR - restingHR);
      final clampedReserve = reserve.clamp(0.0, 1.0);
      trimp += clampedReserve;
      totalHR += hr;
    }

    final avgHR = totalHR / hrSamples.length;
    final workoutMinutes = hrSamples.length; // Assume 1 sample per minute

    final load = TrainingLoad(
      trimp: trimp,
      workoutMinutes: workoutMinutes,
      averageHeartRate: avgHR,
      maxHeartRateUsed: maxHR,
      restingHeartRate: restingHR,
    );

    print('✅ Training load for $date: $load');
    return load;
  }

  /// Get resting HR for a specific date
  static Future<double?> _getRestingHR(String userEmail, DateTime date) async {
    final db = await SecureDatabaseManager.instance.database;
    
    // Try to get resting HR from that specific day
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(Duration(days: 1));

    final results = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        userEmail,
        'RESTING_HEART_RATE',
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return (results.first['value'] as num).toDouble();
    }

    // Fallback: get most recent resting HR from last 7 days
    final weekAgo = date.subtract(Duration(days: 7));
    final fallbackResults = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ? AND timestamp >= ?',
      whereArgs: [
        userEmail,
        'RESTING_HEART_RATE',
        weekAgo.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (fallbackResults.isNotEmpty) {
      return (fallbackResults.first['value'] as num).toDouble();
    }

    return null;
  }

  /// Get heart rate samples during workouts/exercise
  static Future<List<double>> _getWorkoutHeartRates(
    String userEmail,
    DateTime date,
  ) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(Duration(days: 1));

    // Get all HR samples for the day
    final results = await db.query(
      'health_metrics',
      where: 'user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        userEmail,
        'HEART_RATE',
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp ASC',
    );

    if (results.isEmpty) return [];

    // Filter for workout HR (elevated above resting)
    // Simple heuristic: HR > resting + 20 bpm = likely exercise
    final restingHR = await _getRestingHR(userEmail, date) ?? 60;
    final workoutThreshold = restingHR + 20;

    final workoutSamples = results
        .map((r) => (r['value'] as num).toDouble())
        .where((hr) => hr > workoutThreshold)
        .toList();

    return workoutSamples;
  }
}
