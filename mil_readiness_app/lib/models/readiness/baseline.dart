/// Baseline statistics for a specific metric type
/// 
/// Stores 28-day rolling median and MAD (Median Absolute Deviation)
/// for robust z-score calculation.
class Baseline {
  final String metricType;
  final double median;
  final double mad; // Median Absolute Deviation
  final int windowDays;
  final DateTime updatedAt;
  final int sampleCount; // Number of samples in baseline

  const Baseline({
    required this.metricType,
    required this.median,
    required this.mad,
    this.windowDays = 28,
    required this.updatedAt,
    required this.sampleCount,
  });

  /// Check if baseline is valid (has enough samples)
  bool get isValid => sampleCount >= 7; // Minimum 7 days of data

  /// Check if baseline is stale (older than 2 days)
  bool get isStale {
    final age = DateTime.now().difference(updatedAt);
    return age.inDays > 2;
  }

  Map<String, dynamic> toMap(String userEmail) {
    return {
      'user_email': userEmail,
      'metric_type': metricType,
      'median_value': median,
      'mad_value': mad,
      'window_days': windowDays,
      'sample_count': sampleCount,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static Baseline fromMap(Map<String, dynamic> map) {
    return Baseline(
      metricType: map['metric_type'] as String,
      median: (map['median_value'] as num).toDouble(),
      mad: (map['mad_value'] as num).toDouble(),
      windowDays: map['window_days'] as int,
      sampleCount: map['sample_count'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  String toString() {
    return 'Baseline($metricType: median=$median, MAD=$mad, n=$sampleCount)';
  }
}
