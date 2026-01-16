import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Result of baseline calculation
class BaselineResult {
  final double median;
  final double mad; // Median Absolute Deviation
  final int sampleCount;
  final DateTime windowStart;
  final DateTime windowEnd;
  
  const BaselineResult({
    required this.median,
    required this.mad,
    required this.sampleCount,
    required this.windowStart,
    required this.windowEnd,
  });
  
  bool get isValid => sampleCount >= 7; // At least 7 days of data
}

/// Calculates 14-day rolling baselines using robust statistics
class BaselineCalculatorV2 {
  final Database db;
  
  /// 14-day window (not 28 as in v1)
  static const int windowDays = 14;
  
  /// Minimum samples required for reliable baseline
  static const int minSamples = 7;
  
  /// Epsilon to prevent division by zero
  static const double epsilon = 0.001;
  
  /// MAD to sigma conversion factor
  static const double madToSigmaFactor = 1.4826;
  
  BaselineCalculatorV2(this.db);
  
  /// Calculate baseline for a specific metric
  Future<BaselineResult> calculate({
    required String userEmail,
    required String metricType,
    required DateTime endDate,
  }) async {
    final startDate = endDate.subtract(Duration(days: windowDays));
    
    // Fetch data from database
    final rawData = await db.query(
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
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
    );
    
    if (rawData.isEmpty || rawData.length < minSamples) {
      // Insufficient data
      return BaselineResult(
        median: 0,
        mad: 0,
        sampleCount: rawData.length,
        windowStart: startDate,
        windowEnd: endDate,
      );
    }
    
    // Extract values
    final values = rawData
        .map((row) => (row['value'] as num).toDouble())
        .toList();
    
    // Calculate median and MAD
    final median = _calculateMedian(values);
    final mad = _calculateMAD(values, median);
    
    return BaselineResult(
      median: median,
      mad: mad,
      sampleCount: values.length,
      windowStart: startDate,
      windowEnd: endDate,
    );
  }
  
  /// Compute robust z-score with clamping to [-4, +4]
  double computeZScore(double value, BaselineResult baseline) {
    if (!baseline.isValid) {
      return 0.0; // Return neutral if baseline invalid
    }
    
    final double z = (value - baseline.median) / 
                      (madToSigmaFactor * baseline.mad + epsilon);
    
    // Clamp to [-4, +4] to prevent extreme outliers
    return z.clamp(-4.0, 4.0);
  }
  
  /// Calculate median of a list of values
  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final sorted = List<double>.from(values)..sort();
    final n = sorted.length;
    
    if (n % 2 == 1) {
      // Odd number of values
      return sorted[n ~/ 2];
    } else {
      // Even number of values - average the middle two
      return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    }
  }
  
  /// Calculate Median Absolute Deviation
  double _calculateMAD(List<double> values, double median) {
    if (values.isEmpty) return 0.0;
    
    // Compute absolute deviations from median
    final deviations = values
        .map((v) => (v - median).abs())
        .toList();
    
    // Return median of deviations
    return _calculateMedian(deviations);
  }
}
