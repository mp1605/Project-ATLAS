import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Exponentially Weighted Moving Average Calculator
/// Used for calculating acute (7-day) and chronic (28-day) training loads
class EWMACalculator {
  final Database db;
  
  /// Alpha for 7-day EWMA: 2/(7+1) = 0.25
  static const double alpha7d = 2 / (7 + 1);
  
  /// Alpha for 28-day EWMA: 2/(28+1) ≈ 0.069
  static const double alpha28d = 2 / (28 + 1);
  
  EWMACalculator(this.db);
  
  /// Update EWMA with a new value
  /// EWMA_new = α × value + (1-α) × EWMA_old
  Future<double> update({
    required String userEmail,
    required String metricName,
    required double newValue,
    required double alpha,
  }) async {
    // Get previous EWMA value
    final previous = await _getPreviousEWMA(userEmail, metricName);
    
    // Calculate new EWMA
    final newEWMA = alpha * newValue + (1 - alpha) * previous;
    
    // Store updated value
    await _storeEWMA(userEmail, metricName, newEWMA);
    
    return newEWMA;
  }
  
  /// Get current EWMA value
  Future<double> get(String userEmail, String metricName) async {
    return await _getPreviousEWMA(userEmail, metricName);
  }
  
  /// Update 7-day EWMA (acute load)
  Future<double> update7d({
    required String userEmail,
    required String metricName,
    required double value,
  }) async {
    return update(
      userEmail: userEmail,
      metricName: '${metricName}_7d',
      newValue: value,
      alpha: alpha7d,
    );
  }
  
  /// Update 28-day EWMA (chronic load)
  Future<double> update28d({
    required String userEmail,
    required String metricName,
    required double value,
  }) async {
    return update(
      userEmail: userEmail,
      metricName: '${metricName}_28d',
      newValue: value,
      alpha: alpha28d,
    );
  }
  
  /// Get 7-day EWMA
  Future<double> get7d(String userEmail, String metricName) async {
    return get(userEmail, '${metricName}_7d');
  }
  
  /// Get 28-day EWMA
  Future<double> get28d(String userEmail, String metricName) async {
    return get(userEmail, '${metricName}_28d');
  }
  
  /// Get previous EWMA value from database
  Future<double> _getPreviousEWMA(String userEmail, String metricName) async {
    final result = await db.query(
      'ewma_state',
      where: 'user_email = ? AND metric_name = ?',
      whereArgs: [userEmail, metricName],
      limit: 1,
    );
    
    if (result.isEmpty) {
      return 0.0; // No previous value
    }
    
    return (result.first['value'] as num).toDouble();
  }
  
  /// Store EWMA value to database
  Future<void> _storeEWMA(String userEmail, String metricName, double value) async {
    await db.insert(
      'ewma_state',
      {
        'user_email': userEmail,
        'metric_name': metricName,
        'value': value,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
