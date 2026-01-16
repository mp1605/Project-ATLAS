import 'dart:math';
import 'illness_detector.dart';
import 'zscore_calculator.dart';

/// Calculates recovery score using logistic fusion (E1)
/// 
/// v = b1*z_HRV - b2*z_RHR - b3*z_RR - b4*(H/5)
/// REC = 100 * σ(v)
class RecoveryCalculator {
  // Default weights (tunable)
  static const double weightHRV = 1.2; // Higher HRV = better (more weight)
  static const double weightRHR = 1.0; // Lower RHR = better
  static const double weightRR = 0.8;  // Lower RR = better
  static const double weightHypoxia = 0.5;

  /// Calculate recovery score (0-100)
  static Future<double?> calculate({
    required String userEmail,
    required DateTime date,
  }) async {
    // Get illness result (which already computed z-scores)
    final illnessResult = await IllnessDetector.detect(
      userEmail: userEmail,
      date: date,
    );

    if (illnessResult == null) {
      print('⚠️ Cannot calculate recovery - missing illness data');
      return null;
    }

    // Linear combination for recovery (E1)
    final v = weightHRV * illnessResult.zHRV -
              weightRHR * illnessResult.zRHR -
              weightRR * illnessResult.zRR -
              weightHypoxia * (illnessResult.hypoxiaMetric / 5.0);

    // Sigmoid transform to 0-100 scale
    final recoveryScore = 100.0 * _sigmoid(v);

    print('✅ Recovery score for $date: $recoveryScore');
    return recoveryScore;
  }

  /// Sigmoid function
  static double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }
}
