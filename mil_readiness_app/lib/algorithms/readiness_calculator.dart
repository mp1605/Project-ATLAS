import 'dart:math';
import 'recovery_calculator.dart';
import 'sleep_score_calculator.dart';
import 'fitness_calculator.dart';
import 'illness_detector.dart';
import 'banister_model.dart';
import 'baseline_calculator.dart';
import 'training_load_calculator.dart';
import '../models/readiness/readiness_result.dart';

/// Main readiness calculator - combines all components (F1-F2)
/// 
/// Implements final scoring equations:
/// READ = clip(0.45*REC + 0.30*SLP + 0.25*FIT - 0.35*σ(F_norm) - IllPenalty, 0, 100)
/// PHYS = clip(0.55*READ + 0.35*FIT + 0.10*CAP, 0, 100)
class ReadinessCalculator {
  // Final score weights (tunable)
  static const double weightRecovery = 0.45;
  static const double weightSleep = 0.30;
  static const double weightFitness = 0.25;
  static const double weightFatiguePenalty = 0.35;

  static const double weightPhysicalReadiness = 0.55;
  static const double weightPhysicalFitness = 0.35;
  static const double weightPhysicalActivity = 0.10;

  /// Calculate complete readiness for a date
  static Future<ReadinessResult?> calculate({
    required String userEmail,
    required DateTime date,
    int? userAge,
  }) async {
    print('🎯 Calculating readiness for $date...');

    // 1. Get recovery score (E1)
    final recovery = await RecoveryCalculator.calculate(
      userEmail: userEmail,
      date: date,
    );

    if (recovery == null) {
      print('❌ Recovery score missing - cannot calculate readiness');
      return null;
    }

    // 2. Get sleep score (E2)
    final sleepScore = await SleepScoreCalculator.calculate(
      userEmail: userEmail,
      date: date,
    );

    if (sleepScore == null) {
      print('❌ Sleep score missing - cannot calculate readiness');
      return null;
    }

    // 3. Get fitness score (E3)
    final fitness = await FitnessCalculator.calculate(
      userEmail: userEmail,
      date: date,
    ) ?? 50.0; // Default to neutral if missing

    // 4. Get illness result (D)
    final illnessResult = await IllnessDetector.detect(
      userEmail: userEmail,
      date: date,
    );

    final illnessPenalty = illnessResult?.penalty ?? 0.0;
    final illnessProbability = illnessResult?.probability ?? 0.0;

    // 5. Get fatigue state (C1)
    final trainingState = await BanisterModel.getState(userEmail, date);
    final fatigue = trainingState?.fatigue ?? 0.0;

    // Normalize fatigue using baseline
    final fatigueHistory = await BanisterModel.getHistory(
      userEmail: userEmail,
      window: Duration(days: 28),
    );

    double fatiguePenalty = 0.0;
    if (fatigueHistory.isNotEmpty) {
      final fatigueValues = fatigueHistory.map((s) => s.fatigue).toList();
      final meanF = BaselineCalculator.median(fatigueValues);
      final madF = BaselineCalculator.mad(fatigueValues);
      final stdF = 1.4826 * madF;
      
      final fatigueNormalized = (fatigue - meanF) / (stdF + 0.001);
      fatiguePenalty = weightFatiguePenalty * 100 * _sigmoid(fatigueNormalized);
    }

    // 6. Calculate READINESS score (F1)
    final readiness = _clip(
      weightRecovery * recovery +
      weightSleep * sleepScore.totalScore +
      weightFitness * fitness -
      fatiguePenalty -
      illnessPenalty,
      0, 100
    );

    // 7. Calculate PHYSICAL score (F2)
    // Get training load (includes both auto HR data and manual activity entries)
    final trainingLoad = await TrainingLoadCalculator.calculate(
      userEmail: userEmail,
      date: date,
      userAge: userAge,
    );
    
    // Convert training load to activity capacity score (0-100)
    // Higher load = higher activity = higher score (up to a point)
    double activityCapacity = 50.0; // Default neutral
    if (trainingLoad != null && trainingLoad.trimp > 0) {
      // Scale: 0 TRIMP = 30, 50 TRIMP = 70, 100+ TRIMP = 90
      activityCapacity = _clip(30 + (trainingLoad.trimp * 0.6), 20, 95);
      print('   Activity load: ${trainingLoad.trimp.toStringAsFixed(1)} TRIMP → capacity: ${activityCapacity.toStringAsFixed(0)}');
    }
    
    final physical = _clip(
      weightPhysicalReadiness * readiness +
      weightPhysicalFitness * fitness +
      weightPhysicalActivity * activityCapacity,
      0, 100
    );

    // 8. Determine category (H1)
    final category = _categorize(readiness, illnessProbability);

    final result = ReadinessResult(
      readiness: readiness,
      physical: physical,
      category: category,
      components: ComponentScores(
        recovery: recovery,
        sleep: sleepScore.totalScore,
        fitness: fitness,
        fatigueImpact: fatiguePenalty,
      ),
      illnessProbability: illnessProbability,
      illnessPenalty: illnessPenalty,
      date: date,
    );

    print('✅ READINESS COMPLETE: $result');
    print('   Recovery: $recovery, Sleep: ${sleepScore.totalScore}, Fitness: $fitness');
    print('   Fatigue penalty: $fatiguePenalty, Illness penalty: $illnessPenalty');
    
    return result;
  }

  /// Categorize readiness into Go/Caution/No-Go (H1)
  static ReadinessCategory _categorize(double readiness, double illnessProbability) {
    // Go: READ >= 75 AND p_ill < 0.35
    if (readiness >= 75 && illnessProbability < 0.35) {
      return ReadinessCategory.go;
    }
    
    // No-Go: READ < 55 OR p_ill > 0.65
    if (readiness < 55 || illnessProbability > 0.65) {
      return ReadinessCategory.noGo;
    }
    
    // Caution: everything else
    return ReadinessCategory.caution;
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
