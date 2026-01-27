import '../database/secure_database_manager.dart';
import '../models/manual_log.dart';

class ManualLogRepository {
  static const String tableName = 'manual_logs';

  static Future<void> store(ManualLog log) async {
    final db = await SecureDatabaseManager.instance.database;
    await db.insert(
      tableName,
      log.toMap(),
    );
  }

  static Future<List<ManualLog>> getLogs({
    required String userEmail,
    DateTime? startDate,
    DateTime? endDate,
    String? logType,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    String where = 'user_email = ?';
    List<dynamic> whereArgs = [userEmail];

    if (startDate != null) {
      where += ' AND logged_at >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      where += ' AND logged_at <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    if (logType != null) {
      where += ' AND log_type = ?';
      whereArgs.add(logType);
    }

    final results = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'logged_at DESC',
    );

    return results.map((m) => ManualLog.fromMap(m)).toList();
  }

  static Future<void> deleteLog(int id) async {
    final db = await SecureDatabaseManager.instance.database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
