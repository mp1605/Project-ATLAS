import 'package:sqflite_sqlcipher/sqflite.dart';

/// Data quality and sufficiency result
class DataQualityResult {
  final String metricType;
  final int samplesPerDay;
  final int missingDays;
  final int totalDays;
  final String confidence; // 'high', 'medium', 'low'
  final bool isSufficient;
  
  const DataQualityResult({
    required this.metricType,
    required this.samplesPerDay,
    required this.missingDays,
    required this.totalDays,
    required this.confidence,
    required this.isSufficient,
  });
  
  /// Get weight adjustment factor (0.5 to 1.0)
  double get weightAdjustment {
    if (confidence == 'high') return 1.0;
    if (confidence == 'medium') return 0.75;
    return 0.5; // low confidence
  }
}

/// Checks data quality and sufficiency for reliable scoring
class DataSufficiencyChecker {
  final Database db;
  
  /// Minimum samples per day for high confidence
  static const int minSamplesPerDayHigh = 10;
  
  /// Minimum samples per day for medium confidence
  static const int minSamplesPerDayMedium = 3;
  
  /// Maximum missing days for high confidence
  static const int maxMissingDaysHigh = 2;
  
  /// Maximum missing days for medium confidence
  static const int maxMissingDaysMedium = 5;
  
  DataSufficiencyChecker(this.db);
  
  /// Check data quality for a specific metric over a time window
  Future<DataQualityResult> check({
    required String userEmail,
    required String metricType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final totalDays = endDate.difference(startDate).inDays;
    
    // Query data samples
    final samples = await db.query(
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
    
    if (samples.isEmpty) {
      return DataQualityResult(
        metricType: metricType,
        samplesPerDay: 0,
        missingDays: totalDays,
        totalDays: totalDays,
        confidence: 'low',
        isSufficient: false,
      );
    }
    
    // Calculate samples per day
    final samplesPerDay = (samples.length / totalDays).round();
    
    // Count days with data
    final daysWithData = <int>{};
    for (final sample in samples) {
      final timestamp = sample['timestamp'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final dayKey = date.year * 10000 + date.month * 100 + date.day;
      daysWithData.add(dayKey);
    }
    
    final missingDays = totalDays - daysWithData.length;
    
    // Determine confidence level
    final confidence = _determineConfidence(
      samplesPerDay: samplesPerDay,
      missingDays: missingDays,
      totalDays: totalDays,
    );
    
    return DataQualityResult(
      metricType: metricType,
      samplesPerDay: samplesPerDay,
      missingDays: missingDays,
      totalDays: totalDays,
      confidence: confidence,
      isSufficient: confidence != 'low',
    );
  }
  
  /// Check multiple metrics at once
  Future<Map<String, DataQualityResult>> checkMultiple({
    required String userEmail,
    required List<String> metricTypes,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = <String, DataQualityResult>{};
    
    for (final metricType in metricTypes) {
      results[metricType] = await check(
        userEmail: userEmail,
        metricType: metricType,
        startDate: startDate,
        endDate: endDate,
      );
    }
    
    return results;
  }
  
  /// Get overall confidence from multiple metric checks
  String getOverallConfidence(Map<String, DataQualityResult> results) {
    if (results.isEmpty) return 'low';
    
    final lowCount = results.values.where((r) => r.confidence == 'low').length;
    final medCount = results.values.where((r) => r.confidence == 'medium').length;
    final highCount = results.values.where((r) => r.confidence == 'high').length;
    
    // If majority are high, overall is high
    if (highCount > results.length / 2) return 'high';
    
    // If any critical metric is low, overall is low
    if (lowCount > 0) return 'low';
    
    // Otherwise medium
    return 'medium';
  }
  
  /// Determine confidence based on data quality metrics
  String _determineConfidence({
    required int samplesPerDay,
    required int missingDays,
    required int totalDays,
  }) {
    // High confidence: frequent samples, minimal missing data
    if (samplesPerDay >= minSamplesPerDayHigh && 
        missingDays <= maxMissingDaysHigh) {
      return 'high';
    }
    
    // Medium confidence: adequate samples, some missing data OK
    if (samplesPerDay >= minSamplesPerDayMedium && 
        missingDays <= maxMissingDaysMedium) {
      return 'medium';
    }
    
    // Low confidence: sparse data or many missing days
    return 'low';
  }
}
