import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/secure_database_manager.dart';
import '../models/manual_activity_entry.dart';

class ManualActivityRepository {
  static const String tableName = 'manual_activity_entries';

  /// Save or update a manual activity entry
  Future<void> upsert(ManualActivityEntry entry) async {
    final db = await SecureDatabaseManager.instance.database;
    await db.insert(
      tableName,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// List recent activities for a user
  Future<List<ManualActivityEntry>> listRecent({
    required String userEmail,
    int limit = 50,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'user_email = ?',
      whereArgs: [userEmail],
      orderBy: 'start_time_utc DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => ManualActivityEntry.fromMap(maps[i]));
  }

  /// List activities for a specific local day
  Future<List<ManualActivityEntry>> listForDay({
    required String userEmail,
    required DateTime dayLocal,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    // Calculate local day start/end in UTC
    final startLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endLocal = startLocal.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'user_email = ? AND start_time_utc >= ? AND start_time_utc <= ?',
      whereArgs: [
        userEmail,
        startLocal.toUtc().toIso8601String(),
        endLocal.toUtc().toIso8601String(),
      ],
      orderBy: 'start_time_utc DESC',
    );

    return List.generate(maps.length, (i) => ManualActivityEntry.fromMap(maps[i]));
  }

  /// Delete an activity by ID
  Future<void> deleteById(String id) async {
    final db = await SecureDatabaseManager.instance.database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get a single entry by ID
  Future<ManualActivityEntry?> getById(String id) async {
    final db = await SecureDatabaseManager.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ManualActivityEntry.fromMap(maps.first);
  }
}
