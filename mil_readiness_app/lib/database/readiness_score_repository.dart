import '../models/readiness/readiness_result.dart';
import '../database/secure_database_manager.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Repository for storing and retrieving daily readiness scores
class ReadinessScoreRepository {
  /// Store a readiness score for a specific date
  static Future<void> store({
    required String userEmail,
    required DateTime date,
    required ReadinessResult result,
    int dataPointsCount = 0,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    // Normalize date to midnight
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    await db.insert(
      'daily_readiness_scores',
      {
        'user_email': userEmail,
        'date': normalizedDate.millisecondsSinceEpoch,
        'readiness_score': result.readiness,
        'physical_score': result.physical,
        'category': result.category.name,
        'recovery_score': result.components.recovery,
        'sleep_score': result.components.sleep,
        'fitness_score': result.components.fitness,
        'fatigue_impact': result.components.fatigueImpact,
        'illness_probability': result.illnessProbability,
        'illness_penalty': result.illnessPenalty,
        'calculated_at': DateTime.now().millisecondsSinceEpoch,
        'data_points_count': dataPointsCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('✅ Stored readiness score for ${normalizedDate.toLocal()}: ${result.readiness.toStringAsFixed(0)}');
  }

  /// Get score for a specific date
  static Future<ReadinessResult?> getScore({
    required String userEmail,
    required DateTime date,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    final results = await db.query(
      'daily_readiness_scores',
      where: 'user_email = ? AND date = ?',
      whereArgs: [userEmail, normalizedDate.millisecondsSinceEpoch],
    );

    if (results.isEmpty) return null;
    
    final row = results.first;
    
    return ReadinessResult(
      readiness: (row['readiness_score'] as num).toDouble(),
      physical: (row['physical_score'] as num).toDouble(),
      category: ReadinessCategory.values.firstWhere(
        (c) => c.name == row['category'] as String,
      ),
      components: ComponentScores(
        recovery: (row['recovery_score'] as num?)?.toDouble() ?? 0,
        sleep: (row['sleep_score'] as num?)?.toDouble() ?? 0,
        fitness: (row['fitness_score'] as num?)?.toDouble() ?? 0,
        fatigueImpact: (row['fatigue_impact'] as num?)?.toDouble() ?? 0,
      ),
      illnessProbability: (row['illness_probability'] as num?)?.toDouble() ?? 0,
      illnessPenalty: (row['illness_penalty'] as num?)?.toDouble() ?? 0,
      date: normalizedDate,
    );
  }

  /// Get scores for a date range
  static Future<List<ReadinessResult>> getScoresInRange({
    required String userEmail,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final results = await db.query(
      'daily_readiness_scores',
      where: 'user_email = ? AND date >= ? AND date <= ?',
      whereArgs: [
        userEmail,
        DateTime(start.year, start.month, start.day).millisecondsSinceEpoch,
        DateTime(end.year, end.month, end.day).millisecondsSinceEpoch,
      ],
      orderBy: 'date ASC',
    );

    return results.map((row) {
      final date = DateTime.fromMillisecondsSinceEpoch(row['date'] as int);
      
      return ReadinessResult(
        readiness: (row['readiness_score'] as num).toDouble(),
        physical: (row['physical_score'] as num).toDouble(),
        category: ReadinessCategory.values.firstWhere(
          (c) => c.name == row['category'] as String,
        ),
        components: ComponentScores(
          recovery: (row['recovery_score'] as num?)?.toDouble() ?? 0,
          sleep: (row['sleep_score'] as num?)?.toDouble() ?? 0,
          fitness: (row['fitness_score'] as num?)?.toDouble() ?? 0,
          fatigueImpact: (row['fatigue_impact'] as num?)?.toDouble() ?? 0,
        ),
        illnessProbability: (row['illness_probability'] as num?)?.toDouble() ?? 0,
        illnessPenalty: (row['illness_penalty'] as num?)?.toDouble() ?? 0,
        date: date,
      );
    }).toList();
  }

  /// Check if score exists for date
  static Future<bool> hasScoreForDate({
    required String userEmail,
    required DateTime date,
  }) async {
    final score = await getScore(userEmail: userEmail, date: date);
    return score != null;
  }

  /// Delete scores older than retention period
  static Future<int> deleteOldScores({
    required String userEmail,
    required Duration retentionPeriod,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final cutoffDate = DateTime.now().subtract(retentionPeriod);
    
    return await db.delete(
      'daily_readiness_scores',
      where: 'user_email = ? AND date < ?',
      whereArgs: [userEmail, cutoffDate.millisecondsSinceEpoch],
    );
  }

  /// Get latest score
  static Future<ReadinessResult?> getLatestScore(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final results = await db.query(
      'daily_readiness_scores',
      where: 'user_email = ?',
      whereArgs: [userEmail],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    
    final row = results.first;
    final date = DateTime.fromMillisecondsSinceEpoch(row['date'] as int);
    
    return ReadinessResult(
      readiness: (row['readiness_score'] as num).toDouble(),
      physical: (row['physical_score'] as num).toDouble(),
      category: ReadinessCategory.values.firstWhere(
        (c) => c.name == row['category'] as String,
      ),
      components: ComponentScores(
        recovery: (row['recovery_score'] as num?)?.toDouble() ?? 0,
        sleep: (row['sleep_score'] as num?)?.toDouble() ?? 0,
        fitness: (row['fitness_score'] as num?)?.toDouble() ?? 0,
        fatigueImpact: (row['fatigue_impact'] as num?)?.toDouble() ?? 0,
      ),
      illnessProbability: (row['illness_probability'] as num?)?.toDouble() ?? 0,
      illnessPenalty: (row['illness_penalty'] as num?)?.toDouble() ?? 0,
      date: date,
    );
  }
}
