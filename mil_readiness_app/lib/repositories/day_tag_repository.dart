import '../database/secure_database_manager.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Repository for managing daily context tags
class DayTagRepository {
  static const String tableName = 'day_tags';

  /// Adds a tag to a specific date
  static Future<void> addTag({
    required String userEmail,
    required DateTime date,
    required String tag,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final dateTimestamp = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

    await db.insert(
      tableName,
      {
        'user_email': userEmail,
        'date': dateTimestamp,
        'tag': tag,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes a tag from a specific date
  static Future<void> removeTag({
    required String userEmail,
    required DateTime date,
    required String tag,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final dateTimestamp = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

    await db.delete(
      tableName,
      where: 'user_email = ? AND date = ? AND tag = ?',
      whereArgs: [userEmail, dateTimestamp, tag],
    );
  }

  /// Gets all tags for a specific date
  static Future<List<String>> getTagsForDate({
    required String userEmail,
    required DateTime date,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final dateTimestamp = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

    final results = await db.query(
      tableName,
      where: 'user_email = ? AND date = ?',
      whereArgs: [userEmail, dateTimestamp],
    );

    return results.map((row) => row['tag'] as String).toList();
  }

  /// Gets tag frequencies and correlations for a user (placeholder logic)
  static Future<Map<String, int>> getTagStats(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final results = await db.rawQuery('''
      SELECT tag, COUNT(*) as count 
      FROM $tableName 
      WHERE user_email = ? 
      GROUP BY tag 
      ORDER BY count DESC
    ''', [userEmail]);

    return {
      for (var row in results) row['tag'] as String: row['count'] as int
    };
  }
}
