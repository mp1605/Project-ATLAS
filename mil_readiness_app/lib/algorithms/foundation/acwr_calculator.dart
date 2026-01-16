import 'dart:math' as math;
import 'ewma_calculator.dart';

/// ACWR (Acute:Chronic Workload Ratio) Result
class ACWRResult {
  final double acwr;
  final double acuteLoad; // 7-day EWMA
  final double chronicLoad; // 28-day EWMA
  final String riskCategory;
  
  const ACWRResult({
    required this.acwr,
    required this.acuteLoad,
    required this.chronicLoad,
    required this.riskCategory,
  });
  
  bool get isOptimal => acwr >= 0.8 && acwr <= 1.3;
  bool get isElevatedRisk => acwr > 1.3 && acwr < 1.5;
  bool get isHighRisk => acwr >= 1.5;
  bool get isUndertraining => acwr < 0.8;
}

/// ACWR (Acute:Chronic Workload Ratio) Calculator
/// Used for injury risk prediction based on training load spikes
class ACWRCalculator {
  final EWMACalculator ewma;
  
  /// Epsilon to prevent division by zero
  static const double epsilon = 0.001;
  
  ACWRCalculator(this.ewma);
  
  /// Calculate ACWR from current EWMA values
  /// ACWR = AcuteLoad (7d) / ChronicLoad (28d)
  Future<ACWRResult> calculate(String userEmail, String metricName) async {
    final acuteLoad = await ewma.get7d(userEmail, metricName);
    final chronicLoad = await ewma.get28d(userEmail, metricName);
    
    final acwr = acuteLoad / (chronicLoad + epsilon);
    
    return ACWRResult(
      acwr: acwr,
      acuteLoad: acuteLoad,
      chronicLoad: chronicLoad,
      riskCategory: _categorizeRisk(acwr),
    );
  }
  
  /// Categorize injury risk based on ACWR value
  /// Based on research by Gabbett (2016)
  String _categorizeRisk(double acwr) {
    if (acwr < 0.8) {
      return 'undertraining'; // Risk of detraining
    } else if (acwr >= 0.8 && acwr <= 1.3) {
      return 'optimal'; // Sweet spot
    } else if (acwr > 1.3 && acwr < 1.5) {
      return 'elevated'; // Elevated injury risk
    } else {
      return 'high'; // High injury risk (training spike)
    }
  }
  
  /// Get risk score (0-100, higher = more risk)
  /// Used in Injury Risk Indicator (Score #8)
  double getRiskScore(double acwr) {
    // Map ACWR to risk score using sigmoid
    // Center at 1.2, scale 0.1
    final u = (acwr - 1.2) / 0.1;
    final sigmoid = 1 / (1 + math.exp(-u));
    return (sigmoid * 100).clamp(0, 100);
  }
}
