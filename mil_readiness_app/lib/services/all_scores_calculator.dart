import '../database/secure_database_manager.dart';
import '../models/user_profile.dart';
import '../models/comprehensive_readiness_result.dart';
import '../algorithms/foundation/baseline_calculator_v2.dart';
import '../algorithms/foundation/data_sufficiency_checker.dart';
import '../algorithms/core_scores/overall_readiness.dart';
import '../algorithms/core_scores/recovery_score.dart';
import '../algorithms/core_scores/fatigue_index.dart';
import '../algorithms/core_scores/endurance_capacity.dart';
import '../algorithms/core_scores/sleep_index.dart';
import '../algorithms/core_scores/cardiovascular_fitness.dart';
import '../algorithms/safety_scores/all_safety_scores.dart';
import '../algorithms/specialty_scores/all_specialty_scores.dart';
import '../algorithms/foundation/ewma_calculator.dart';
import '../algorithms/foundation/acwr_calculator.dart';
import '../algorithms/foundation/trimp_calculator.dart';
import 'dashboard_sync_service.dart';
import '../config/app_config.dart';

/// Service to calculate all 18 military readiness scores in a coordinated manner
class AllScoresCalculator {
  final SecureDatabaseManager db;
  
  AllScoresCalculator({required this.db});
  
  /// Calculate all 18 scores for the given user and date
  Future<ComprehensiveReadinessResult> calculateAll({
    required String userEmail,
    required DateTime date,
    required UserProfile profile,
  }) async {
    print('🎯 Calculating all 18 scores for $userEmail on ${date.toLocal()}');
    
    // Get the raw database from the manager
    final rawDb = await db.database;
    
    // Initialize foundation services
    final baseline = BaselineCalculatorV2(rawDb);
    final dataCheck = DataSufficiencyChecker(rawDb);
    final ewma = EWMACalculator(rawDb);
    final acwr = ACWRCalculator(ewma);
    final trimp = TRIMPCalculator();
    
    // Initialize all calculators with raw database and foundation services
    final recoveryCalc = RecoveryScoreCalculator(db: rawDb, baseline: baseline, dataCheck: dataCheck);
    final fatigueCalc = FatigueIndexCalculator(
      db: rawDb, 
      baseline: baseline, 
      ewma: ewma,
      acwr: acwr,
      trimp: trimp,
    );
    final enduranceCalc = EnduranceCapacityCalculator(db: rawDb, baseline: baseline);
    final sleepCalc = SleepIndexCalculator(db: rawDb, baseline: baseline);
    final cardioCalc = CardiovascularFitnessCalculator(db: rawDb, baseline: baseline);
    
    final safetyScores = AllSafetyScoresCalculator(db: rawDb);
    final specialtyScores = AllSpecialtyScoresCalculator(db: rawDb);
    
    // Track confidence levels
    final Map<String, String> confidenceLevels = {};
    
    // ===== CORE SCORES (2-6) =====
    print('  📊 Calculating core scores...');
    
    final recovery = await recoveryCalc.calculate(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Recovery'] = recovery.confidence;
    
    final sleep = await sleepCalc.calculate(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    confidenceLevels['Sleep Index'] = sleep.confidence;
    
    final fatigue = await fatigueCalc.calculate(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    confidenceLevels['Fatigue Index'] = fatigue.confidence;
    
    final endurance = await enduranceCalc.calculate(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Endurance'] = endurance.confidence;
    
    final cardioFitness = await cardioCalc.calculate(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Cardio Fitness'] = cardioFitness.confidence;
    
    // ===== SAFETY SCORES (7-12) =====
    print('  🛡️ Calculating safety scores...');
    
    final stressLoad = await safetyScores.calculateStressLoad(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Stress Load'] = stressLoad.confidence;
    
    final injuryRisk = await safetyScores.calculateInjuryRisk(
      userEmail: userEmail,
      date: date,
      fatigueScore: fatigue.score,
      profile: profile,
    );
    confidenceLevels['Injury Risk'] = injuryRisk.confidence;
    
    final cardioResp = await safetyScores.calculateCardioRespStability(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Cardio-Resp Stability'] = cardioResp.confidence;
    
    final illnessRisk = await safetyScores.calculateIllnessRisk(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    confidenceLevels['Illness Risk'] = illnessRisk.confidence;
    
    final dailyActivity = await safetyScores.calculateDailyActivity(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Daily Activity'] = dailyActivity.confidence;
    
    final workCapacity = await safetyScores.calculateWorkCapacity(
      userEmail: userEmail,
      date: date,
      recoveryScore: recovery.score,
      sleepScore: sleep.score,
    );
    confidenceLevels['Work Capacity'] = workCapacity.confidence;
    
    // ===== SPECIALTY SCORES (13-18) =====
    print('  ⚡ Calculating specialty scores...');
    
    final altitude = await specialtyScores.calculateAltitudeScore(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Altitude'] = altitude.confidence;
    
    final cardiacSafety = await specialtyScores.calculateCardiacSafetyPenalty(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Cardiac Safety'] = cardiacSafety.confidence;
    
    final sleepDebt = await specialtyScores.calculateSleepDebt(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    confidenceLevels['Sleep Debt'] = sleepDebt.confidence;
    
    final trainingReadiness = await specialtyScores.calculateTrainingReadiness(
      userEmail: userEmail,
      date: date,
      recoveryScore: recovery.score,
      sleepScore: sleep.score,
      fatigueScore: fatigue.score,
      injuryRiskScore: injuryRisk.score,
    );
    confidenceLevels['Training Readiness'] = trainingReadiness.confidence;
    
    final cognitiveAlertness = await specialtyScores.calculateCognitiveAlertness(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Cognitive Alertness'] = cognitiveAlertness.confidence;
    
    final thermoreg = await specialtyScores.calculateThermoregulatoryAdaptation(
      userEmail: userEmail,
      date: date,
    );
    confidenceLevels['Thermoregulatory'] = thermoreg.confidence;
    
    // ===== OVERALL READINESS (Score #1) =====
    print('  🎖️ Calculating overall readiness...');
    
    final overallCalc = OverallReadinessCalculator(
      db: rawDb,
      recoveryCalc: recoveryCalc,
      fatigueCalc: fatigueCalc,
      sleepCalc: sleepCalc,
    );
    
    final overall = await overallCalc.calculate(
      userEmail: userEmail,
      date: date,
      profile: profile,
    );
    confidenceLevels['Overall Readiness'] = overall.confidence;
    
    // Determine overall confidence
    final overallConfidence = _determineOverallConfidence(confidenceLevels.values.toList());
    
    // Collect component breakdowns for drill-down
    final Map<String, Map<String, dynamic>> componentBreakdown = {
      'Recovery': recovery.components,
      'Sleep Index': sleep.components,
      'Fatigue Index': fatigue.components,
      'Endurance': endurance.components,
      'Cardio Fitness': cardioFitness.components,
      'Stress Load': stressLoad.components,
      'Injury Risk': injuryRisk.components,
      'Cardio-Resp Stability': cardioResp.components,
      'Illness Risk': illnessRisk.components,
      'Daily Activity': dailyActivity.components,
      'Work Capacity': workCapacity.components,
      'Altitude Score': altitude.components,
      'Cardiac Safety': cardiacSafety.components,
      'Sleep Debt': sleepDebt.components,
      'Training Readiness': trainingReadiness.components,
      'Cognitive Alertness': cognitiveAlertness.components,
      'Thermoregulatory': thermoreg.components,
    };
    
    print('  ✅ All 18 scores calculated successfully');
    print('     Overall: ${overall.score.toStringAsFixed(1)} (${overall.category})');
    print('     Confidence: $overallConfidence');
    
    final result = ComprehensiveReadinessResult(
      overallReadiness: overall.score,
      category: overall.category,
      recoveryScore: recovery.score,
      fatigueIndex: fatigue.score,
      enduranceCapacity: endurance.score,
      sleepIndex: sleep.score,
      cardiovascularFitness: cardioFitness.score,
      stressLoad: stressLoad.score,
      injuryRisk: injuryRisk.score,
      cardioRespStability: cardioResp.score,
      illnessRisk: illnessRisk.score,
      dailyActivity: dailyActivity.score,
      workCapacity: workCapacity.score,
      altitudeScore: altitude.score,
      cardiacSafetyPenalty: cardiacSafety.score,
      sleepDebt: sleepDebt.score,
      trainingReadiness: trainingReadiness.score,
      cognitiveAlertness: cognitiveAlertness.score,
      thermoregulatoryAdaptation: thermoreg.score,
      calculatedAt: DateTime.now(),
      confidenceLevels: confidenceLevels,
      overallConfidence: overallConfidence,
      componentBreakdown: componentBreakdown,
    );
    
    // Sync to dashboard (asynchronous, don't block on failure)
    _syncToDashboard(userEmail, result);
    
    return result;
  }
  
  /// Sync scores to dashboard backend (fire-and-forget)
  void _syncToDashboard(String userEmail, ComprehensiveReadinessResult result) async {
    try {
      final syncService = DashboardSyncService(
        baseUrl: AppConfig.apiBaseUrl,
      );
      
      print('📤 Syncing scores to dashboard for $userEmail...');
      final success = await syncService.syncWithRetry(
        userEmail: userEmail,
        scores: result,
        maxRetries: 2, // Quick retry, don't block too long
      );
      
      if (success) {
        print('✅ Dashboard sync successful');
      } else {
        print('⚠️ Dashboard sync failed (app continues normally)');
      }
    } catch (e) {
      print('⚠️ Dashboard sync error: $e (app continues normally)');
    }
  }
  
  /// Determine overall confidence from individual score confidences
  String _determineOverallConfidence(List<String> confidences) {
    final lowCount = confidences.where((c) => c == 'low').length;
    final highCount = confidences.where((c) => c == 'high').length;
    final total = confidences.length;
    
    if (highCount > total * 0.6) return 'high';
    if (lowCount > total * 0.3) return 'low';
    return 'medium';
  }
}
