import 'dart:math' as math;

/// Training Impulse (TRIMP) Calculator
/// Gender-specific calculation based on Banister model
class TRIMPCalculator {
  /// Calculate TRIMP for a workout
  /// 
  /// Formula:
  /// For men: y = 0.64 × e^(1.92×DHR)
  /// For women: y = 0.86 × e^(1.67×DHR)
  /// TRIMP = duration × DHR × y
  /// 
  /// Where DHR = (HR_exercise - HR_rest) / (HR_max - HR_rest)
  double calculate({
    required int durationMinutes,
    required double avgHeartRate,
    required double restingHeartRate,
    required double maxHeartRate,
    required String gender, // 'male', 'female', 'other'
  }) {
    if (durationMinutes <= 0 || maxHeartRate <= restingHeartRate) {
      return 0.0;
    }
    
    // Heart Rate Reserve ratio
    final dhr = (avgHeartRate - restingHeartRate) / 
                (maxHeartRate - restingHeartRate);
    
    // Clamp DHR to [0, 1]
    final dhrClamped = dhr.clamp(0.0, 1.0);
    
    // Gender-specific exponential factor
    final y = _getExponentialFactor(dhrClamped, gender);
    
    // TRIMP = duration × DHR × y
    return durationMinutes * dhrClamped * y;
  }
  
  /// Calculate TRIMP from workout data
  double calculateFromWorkout({
    required int durationMinutes,
    required List<int> heartRateSamples,
    required double restingHeartRate,
    required double maxHeartRate,
    required String gender,
  }) {
    if (heartRateSamples.isEmpty) {
      return 0.0;
    }
    
    // Calculate average heart rate from samples
    final avgHR = heartRateSamples.reduce((a, b) => a + b) / 
                   heartRateSamples.length;
    
    return calculate(
      durationMinutes: durationMinutes,
      avgHeartRate: avgHR.toDouble(),
      restingHeartRate: restingHeartRate,
      maxHeartRate: maxHeartRate,
      gender: gender,
    );
  }
  
  /// Get gender-specific exponential factor
  /// For men: y = 0.64 × e^(1.92×DHR)
  /// For women: y = 0.86 × e^(1.67×DHR)
  /// Default (other): average of both
  double _getExponentialFactor(double dhr, String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
      case 'm':
        return 0.64 * math.exp(1.92 * dhr);
        
      case 'female':
      case 'f':
        return 0.86 * math.exp(1.67 * dhr);
        
      default:
        // For 'other' or unknown, use average
        final male = 0.64 * math.exp(1.92 * dhr);
        final female = 0.86 * math.exp(1.67 * dhr);
        return (male + female) / 2;
    }
  }
  
  /// Estimate workout intensity zone from DHR
  /// Returns: 'recovery', 'aerobic', 'threshold', 'anaerobic', 'max'
  String getIntensityZone(double dhr) {
    if (dhr < 0.6) return 'recovery';
    if (dhr < 0.7) return 'aerobic';
    if (dhr < 0.8) return 'threshold';
    if (dhr < 0.9) return 'anaerobic';
    return 'max';
  }
}
