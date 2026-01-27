import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/secure_database_manager.dart';
import '../models/comprehensive_readiness_result.dart';

/// Repository for storing and retrieving the full 18 military readiness scores
class ComprehensiveScoreRepository {
  static const String tableName = 'daily_readiness_scores';

  /// Store the full 18-score result for a specific user and date
  static Future<void> store({
    required String userEmail,
    required DateTime date,
    required ComprehensiveReadinessResult result,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    // Normalize date to midnight (timestamp)
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateTimestamp = normalizedDate.millisecondsSinceEpoch;

    final Map<String, dynamic> row = {
      'user_email': userEmail,
      'date': dateTimestamp,
      'overall_readiness': result.overallReadiness,
      'recovery_score': result.recoveryScore,
      'fatigue_index': result.fatigueIndex,
      'endurance_capacity': result.enduranceCapacity,
      'sleep_index': result.sleepIndex,
      'cardiovascular_fitness': result.cardiovascularFitness,
      'stress_load': result.stressLoad,
      'injury_risk': result.injuryRisk,
      'cardio_resp_stability': result.cardioRespStability,
      'illness_risk': result.illnessRisk,
      'daily_activity': result.dailyActivity,
      'work_capacity': result.workCapacity,
      'altitude_score': result.altitudeScore,
      'cardiac_safety_penalty': result.cardiacSafetyPenalty,
      'sleep_debt': result.sleepDebt,
      'training_readiness': result.trainingReadiness,
      'cognitive_alertness': result.cognitiveAlertness,
      'thermoregulatory_adaptation': result.thermoregulatoryAdaptation,
      'category': result.category,
      'calculated_at': result.calculatedAt.millisecondsSinceEpoch,
      'confidence': result.overallConfidence,
      // Metadata as JSON string
      'coverage': jsonEncode(result.confidenceLevels),
    };

    await db.insert(
      tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('📦 Persisted comprehensive scores for $userEmail on ${normalizedDate.toLocal()}');
  }

  /// Get scores for the last [days] for trend visualization
  static Future<List<ComprehensiveReadinessResult>> getTrend({
    required String userEmail,
    int days = 7,
    DateTime? endDate,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final end = endDate ?? DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    
    final startTime = DateTime(start.year, start.month, start.day).millisecondsSinceEpoch;
    final endTime = DateTime(end.year, end.month, end.day).millisecondsSinceEpoch;

    final results = await db.query(
      tableName,
      where: 'user_email = ? AND date >= ? AND date <= ?',
      whereArgs: [userEmail, startTime, endTime],
      orderBy: 'date ASC',
    );

    return results.map((row) => _fromMap(row)).toList();
  }

  /// Helper to convert DB row back to model
  static ComprehensiveReadinessResult _fromMap(Map<String, dynamic> row) {
    return ComprehensiveReadinessResult(
      overallReadiness: (row['overall_readiness'] as num).toDouble(),
      category: row['category'] as String,
      recoveryScore: (row['recovery_score'] as num).toDouble(),
      fatigueIndex: (row['fatigue_index'] as num).toDouble(),
      enduranceCapacity: (row['endurance_capacity'] as num).toDouble(),
      sleepIndex: (row['sleep_index'] as num).toDouble(),
      cardiovascularFitness: (row['cardiovascular_fitness'] as num).toDouble(),
      stressLoad: (row['stress_load'] as num).toDouble(),
      injuryRisk: (row['injury_risk'] as num).toDouble(),
      cardioRespStability: (row['cardio_resp_stability'] as num).toDouble(),
      illnessRisk: (row['illness_risk'] as num).toDouble(),
      dailyActivity: (row['daily_activity'] as num).toDouble(),
      workCapacity: (row['work_capacity'] as num).toDouble(),
      altitudeScore: (row['altitude_score'] as num).toDouble(),
      cardiacSafetyPenalty: (row['cardiac_safety_penalty'] as num).toDouble(),
      sleepDebt: (row['sleep_debt'] as num).toDouble(),
      trainingReadiness: (row['training_readiness'] as num).toDouble(),
      cognitiveAlertness: (row['cognitive_alertness'] as num).toDouble(),
      thermoregulatoryAdaptation: (row['thermoregulatory_adaptation'] as num).toDouble(),
      calculatedAt: DateTime.fromMillisecondsSinceEpoch(row['calculated_at'] as int),
      overallConfidence: row['confidence'] as String? ?? 'medium',
      confidenceLevels: Map<String, String>.from(jsonDecode(row['coverage'] as String? ?? '{}')),
    );
  }
}
