import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/readiness/training_state.dart';
import 'training_load_calculator.dart';
import '../database/secure_database_manager.dart';

/// Banister impulse-response model for training adaptation (C1-C3)
/// 
/// Models two physiological states:
/// - Fatigue (F): Fast decay (~7 days), negative impact
/// - Fitness (P): Slow decay (~42 days), positive impact
/// - Training Effect: TE = P - F
/// 
/// Update equations:
/// F_t = F_(t-1) * e^(-1/τF) + kF * L_t
/// P_t = P_(t-1) * e^(-1/τP) + kP * L_t
class BanisterModel {
  // Decay time constants (tunable)
  static const double fatigueTau = 7.0;  // Days - fast decay
  static const double fitnessTau = 42.0; // Days - slow decay
  
  // Gain coefficients (tunable)
  static const double fatigueGain = 1.0;
  static const double fitnessGain = 1.0;

  /// Update training state for a new day
  static Future<TrainingState> updateState({
    required String userEmail,
    required DateTime date,
    int? userAge,
  }) async {
    // Get previous state
    final previousState = await _getPreviousState(userEmail, date);
    
    // Get training load (TRIMP) for this date
    final trainingLoad = await TrainingLoadCalculator.calculate(
      userEmail: userEmail,
      date: date,
      userAge: userAge,
    );

    final trimp = trainingLoad?.trimp ?? 0.0;

    // Calculate decay factors
    final fatigueDecay = exp(-1.0 / fatigueTau);
    final fitnessDecay = exp(-1.0 / fitnessTau);

    // Update states (C1, C2)
    final fatigue = previousState.fatigue * fatigueDecay + fatigueGain * trimp;
    final fitness = previousState.fitness * fitnessDecay + fitnessGain * trimp;

    // Training effect (C3)
    final trainingEffect = fitness - fatigue;

    final newState = TrainingState(
      fatigue: fatigue,
      fitness: fitness,
      trainingEffect: trainingEffect,
      date: date,
    );

    // Save to database
    await _saveState(userEmail, newState);

    print('✅ Banister model updated for $date: $newState');
    return newState;
  }

  /// Get training state for a specific date
  static Future<TrainingState?> getState(
    String userEmail,
    DateTime date,
  ) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(Duration(days: 1));

    final results = await db.query(
      'training_state',
      where: 'user_email = ? AND date >= ? AND date < ?',
      whereArgs: [
        userEmail,
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
      ],
      limit: 1,
    );

    if (results.isEmpty) return null;
    
    return TrainingState.fromMap(results.first);
  }

  /// Get previous day's state (or initialize if first day)
  static Future<TrainingState> _getPreviousState(
    String userEmail,
    DateTime date,
  ) async {
    final yesterday = date.subtract(Duration(days: 1));
    final previousState = await getState(userEmail, yesterday);

    if (previousState != null) {
      return previousState;
    }

    // No previous state - initialize both to zero
    print('ℹ️ Initializing Banister model for $userEmail');
    return TrainingState(
      fatigue: 0.0,
      fitness: 0.0,
      trainingEffect: 0.0,
      date: yesterday,
    );
  }

  /// Save training state to database
  static Future<void> _saveState(
    String userEmail,
    TrainingState state,
  ) async {
    final db = await SecureDatabaseManager.instance.database;

    await db.insert(
      'training_state',
      state.toMap(userEmail),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get training history for trend analysis
  static Future<List<TrainingState>> getHistory({
    required String userEmail,
    required Duration window,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final end = DateTime.now();
    final start = end.subtract(window);

    final results = await db.query(
      'training_state',
      where: 'user_email = ? AND date >= ?',
      whereArgs: [userEmail, start.millisecondsSinceEpoch],
      orderBy: 'date ASC',
    );

    return results.map((r) => TrainingState.fromMap(r)).toList();
  }
}
