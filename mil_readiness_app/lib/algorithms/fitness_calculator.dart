import 'dart:math';
import 'banister_model.dart';
import 'baseline_calculator.dart';

/// Calculates fitness score from VO2max and training effect (E3)
/// 
/// FIT = clip(60*σ(z_VO2) + 40*σ((TE - μTE) / σTE), 0, 100)
/// 
/// Note: VO2max not directly available from Apple Watch,
/// so we estimate from training effect primarily
class FitnessCalculator {
  /// Calculate fitness score (0-100)
  static Future<double?> calculate({
    required String userEmail,
    required DateTime date,
  }) async {
    // Get training state
    final trainingState = await BanisterModel.getState(userEmail, date);
    
    if (trainingState == null) {
      print('⚠️ No training state for fitness calculation on $date');
      return null;
    }

    // Get training effect baseline statistics (last 28 days)
    final teHistory = await BanisterModel.getHistory(
      userEmail: userEmail,
      window: Duration(days: 28),
    );

    if (teHistory.isEmpty) {
      // First day - return neutral score
      return 50.0;
    }

    // Calculate TE mean and std dev
    final teValues = teHistory.map((s) => s.trainingEffect).toList();
    final meanTE = BaselineCalculator.median(teValues); // Use median for robustness
    final madTE = BaselineCalculator.mad(teValues);
    final stdTE = 1.4826 * madTE; // Convert MAD to approx std dev

    // Normalize current training effect
    final teNormalized = (trainingState.trainingEffect - meanTE) / (stdTE + 0.001);

    // Since we don't have VO2max, weight training effect more heavily
    // In future: integrate actual VO2max if available from fitness tests
    final vo2Component = 0.0; // Placeholder - would be 60*σ(z_VO2)
    final teComponent = 100.0 * _sigmoid(teNormalized); // Full weight on TE

    final fitnessScore = _clip(vo2Component + teComponent, 0, 100);

    print('✅ Fitness score for $date: $fitnessScore (TE=${trainingState.trainingEffect})');
    return fitnessScore;
  }

  /// Sigmoid function
  static double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  /// Clip value to range
  static double _clip(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
