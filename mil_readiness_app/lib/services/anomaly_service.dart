import 'dart:math';
import '../models/comprehensive_readiness_result.dart';

class AnomalyAlert {
  final String metric;
  final double zScore;
  final String message;
  final String tacticalRecommendation;
  final bool isCritical;

  AnomalyAlert({
    required this.metric,
    required this.zScore,
    required this.message,
    required this.tacticalRecommendation,
    this.isCritical = false,
  });
}

class AnomalyService {
  /// Detects physiological anomalies by comparing the latest result against historical trends
  static List<AnomalyAlert> detect(
      ComprehensiveReadinessResult latest, 
      List<ComprehensiveReadinessResult> history
  ) {
    if (history.length < 7) return []; // Need at least a week to establish baseline

    List<AnomalyAlert> alerts = [];

    // 1. Overall Readiness Anomaly
    final readinessAlert = _checkMetric(
      'Readiness',
      latest.overallReadiness,
      history.map((e) => e.overallReadiness).toList(),
      'Significant drop in operational readiness detected.',
      'Recommend light duty and focused recovery protocol.'
    );
    if (readinessAlert != null) alerts.add(readinessAlert);

    // 2. Recovery (HRV-based) Anomaly
    final recoveryAlert = _checkMetric(
      'Recovery',
      latest.recoveryScore,
      history.map((e) => e.recoveryScore).toList(),
      'Elevated physiological strain detected (HRV deviation).',
      'Monitor for onset of illness or overtraining. Defer high-intensity load.'
    );
    if (recoveryAlert != null) alerts.add(recoveryAlert);

    // 3. Sleep Index Anomaly
    final sleepAlert = _checkMetric(
      'Sleep',
      latest.sleepIndex,
      history.map((e) => e.sleepIndex).toList(),
      'Abnormal sleep architecture or duration detected.',
      'Cognitive performance may be degraded. Avoid high-stakes decision making.'
    );
    if (sleepAlert != null) alerts.add(sleepAlert);

    return alerts;
  }

  static AnomalyAlert? _checkMetric(
    String name, 
    double current, 
    List<double> values,
    String message,
    String recommendation
  ) {
    if (values.isEmpty) return null;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);

    if (stdDev < 1.0) return null; // Avoid division by zero or jittery alerts

    final zScore = (current - mean) / stdDev;

    // Threshold: -2.0 is generally considered a significant anomaly (95th percentile)
    if (zScore < -2.0) {
      return AnomalyAlert(
        metric: name,
        zScore: zScore,
        message: message,
        tacticalRecommendation: recommendation,
        isCritical: zScore < -3.0,
      );
    }

    return null;
  }
}
