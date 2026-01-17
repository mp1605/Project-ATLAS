/// Comprehensive result containing all 18 military readiness scores
class ComprehensiveReadinessResult {
  // Score #1: Overall Readiness (Master Score)
  final double overallReadiness;
  final String category; // 'GO', 'CAUTION', 'LIMITED', 'STOP'
  
  // Core Scores (2-6)
  final double recoveryScore;
  final double fatigueIndex;
  final double enduranceCapacity;
  final double sleepIndex;
  final double cardiovascularFitness;
  
  // Safety Scores (7-12)
  final double stressLoad;
  final double injuryRisk;
  final double cardioRespStability;
  final double illnessRisk;
  final double dailyActivity;
  final double workCapacity;
  
  // Specialty Scores (13-18)
  final double altitudeScore;
  final double cardiacSafetyPenalty;
  final double sleepDebt;
  final double trainingReadiness;
  final double cognitiveAlertness;
  final double thermoregulatoryAdaptation;
  
  // Metadata
  final DateTime calculatedAt;
  final Map<String, String> confidenceLevels; // score name -> 'high'/'medium'/'low'
  final String overallConfidence;
  final Map<String, Map<String, dynamic>> componentBreakdown; // score name -> {component -> value}
  
  const ComprehensiveReadinessResult({
    required this.overallReadiness,
    required this.category,
    required this.recoveryScore,
    required this.fatigueIndex,
    required this.enduranceCapacity,
    required this.sleepIndex,
    required this.cardiovascularFitness,
    required this.stressLoad,
    required this.injuryRisk,
    required this.cardioRespStability,
    required this.illnessRisk,
    required this.dailyActivity,
    required this.workCapacity,
    required this.altitudeScore,
    required this.cardiacSafetyPenalty,
    required this.sleepDebt,
    required this.trainingReadiness,
    required this.cognitiveAlertness,
    required this.thermoregulatoryAdaptation,
    required this.calculatedAt,
    required this.confidenceLevels,
    required this.overallConfidence,
    this.componentBreakdown = const {},
  });
  
  /// Get all scores as a map for easy iteration
  Map<String, double> getAllScores() {
    return {
      'Overall Readiness': overallReadiness,
      'Recovery': recoveryScore,
      'Fatigue Index': fatigueIndex,
      'Endurance': enduranceCapacity,
      'Sleep Index': sleepIndex,
      'Cardio Fitness': cardiovascularFitness,
      'Stress Load': stressLoad,
      'Injury Risk': injuryRisk,
      'Cardio-Resp Stability': cardioRespStability,
      'Illness Risk': illnessRisk,
      'Daily Activity': dailyActivity,
      'Work Capacity': workCapacity,
      'Altitude': altitudeScore,
      'Cardiac Safety': cardiacSafetyPenalty,
      'Sleep Debt': sleepDebt,
      'Training Readiness': trainingReadiness,
      'Cognitive Alertness': cognitiveAlertness,
      'Thermoregulatory': thermoregulatoryAdaptation,
    };
  }
  
  /// Get scores grouped by category
  Map<String, Map<String, double>> getScoresByCategory() {
    return {
      'Core': {
        'Recovery': recoveryScore,
        'Sleep Index': sleepIndex,
        'Fatigue Index': fatigueIndex,
        'Endurance': enduranceCapacity,
        'Cardio Fitness': cardiovascularFitness,
        'Work Capacity': workCapacity,
      },
      'Safety': {
        'Stress Load': stressLoad,
        'Injury Risk': injuryRisk,
        'Cardio-Resp Stability': cardioRespStability,
        'Illness Risk': illnessRisk,
        'Daily Activity': dailyActivity,
        'Cardiac Safety': cardiacSafetyPenalty,
      },
      'Specialty': {
        'Altitude': altitudeScore,
        'Sleep Debt': sleepDebt,
        'Training Readiness': trainingReadiness,
        'Cognitive Alertness': cognitiveAlertness,
        'Thermoregulatory': thermoregulatoryAdaptation,
      },
    };
  }
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'overall_readiness': overallReadiness,
      'category': category,
      'recovery_score': recoveryScore,
      'fatigue_index': fatigueIndex,
      'endurance_capacity': enduranceCapacity,
      'sleep_index': sleepIndex,
      'cardiovascular_fitness': cardiovascularFitness,
      'stress_load': stressLoad,
      'injury_risk': injuryRisk,
      'cardio_resp_stability': cardioRespStability,
      'illness_risk': illnessRisk,
      'daily_activity': dailyActivity,
      'work_capacity': workCapacity,
      'altitude_score': altitudeScore,
      'cardiac_safety_penalty': cardiacSafetyPenalty,
      'sleep_debt': sleepDebt,
      'training_readiness': trainingReadiness,
      'cognitive_alertness': cognitiveAlertness,
      'thermoregulatory_adaptation': thermoregulatoryAdaptation,
      'calculated_at': calculatedAt.toIso8601String(),
      'confidence_levels': confidenceLevels,
      'overall_confidence': overallConfidence,
    };
  }
}
