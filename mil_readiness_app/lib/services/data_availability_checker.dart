import '../database/secure_database_manager.dart';
import '../database/health_data_repository.dart';
import '../algorithms/baseline_calculator.dart';

/// Checks data availability for readiness calculations
class DataAvailabilityChecker {
  /// Check if enough data exists for readiness calculation
  static Future<DataAvailabilityResult> check(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(Duration(days: 7));
    final twentyEightDaysAgo = now.subtract(Duration(days: 28));

    // Count metrics in last 7 days
    final recent7Days = await _countMetrics(db, userEmail, sevenDaysAgo, now);
    
    // Count metrics in last 28 days
    final recent28Days = await _countMetrics(db, userEmail, twentyEightDaysAgo, now);

    // Check specific critical metrics
    final hasHRV = await _hasMetric(db, userEmail, 'HEART_RATE_VARIABILITY_SDNN', sevenDaysAgo, now);
    final hasRHR = await _hasMetric(db, userEmail, 'RESTING_HEART_RATE', sevenDaysAgo, now);
    final hasSleep = await _hasMetric(db, userEmail, 'SLEEP_ASLEEP', sevenDaysAgo, now);

    final canCalculate = recent7Days >= 7 && hasHRV && hasRHR && hasSleep;
    final optimal = recent28Days >= 28;

    return DataAvailabilityResult(
      totalMetrics7Days: recent7Days,
      totalMetrics28Days: recent28Days,
      hasHRV: hasHRV,
      hasRHR: hasRHR,
      hasSleep: hasSleep,
      canCalculateReadiness: canCalculate,
      isOptimal: optimal,
    );
  }

  static Future<int> _countMetrics(
    dynamic db,
    String userEmail,
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM health_metrics 
      WHERE user_email = ? AND timestamp >= ? AND timestamp < ?
    ''', [userEmail, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);

    return result.first['count'] as int;
  }

  static Future<bool> _hasMetric(
    dynamic db,
    String userEmail,
    String metricType,
    DateTime start,
    DateTime end,
  ) async {
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM health_metrics 
      WHERE user_email = ? AND metric_type = ? AND timestamp >= ? AND timestamp < ?
    ''', [userEmail, metricType, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);

    return (result.first['count'] as int) > 0;
  }
}

class DataAvailabilityResult {
  final int totalMetrics7Days;
  final int totalMetrics28Days;
  final bool hasHRV;
  final bool hasRHR;
  final bool hasSleep;
  final bool canCalculateReadiness;
  final bool isOptimal;

  DataAvailabilityResult({
    required this.totalMetrics7Days,
    required this.totalMetrics28Days,
    required this.hasHRV,
    required this.hasRHR,
    required this.hasSleep,
    required this.canCalculateReadiness,
    required this.isOptimal,
  });

  String get statusMessage {
    if (canCalculateReadiness) {
      if (isOptimal) {
        return '✅ Optimal data available (28+ days)';
      } else {
        return '✅ Sufficient data (7+ days)';
      }
    } else {
      final missing = <String>[];
      if (!hasHRV) missing.add('HRV');
      if (!hasRHR) missing.add('Resting HR');
      if (!hasSleep) missing.add('Sleep');
      
      return '⚠️ Waiting for data: ${missing.join(", ")}\n'
             'Metrics collected: $totalMetrics7Days (need 7+ days)';
    }
  }
}
