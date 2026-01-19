import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/secure_database_manager.dart';
import '../models/manual_sleep_entry.dart';

/// Repository for managing manual sleep entries in encrypted local database
/// 
/// Privacy-first: All data stays local, never synced to backend/dashboard.
/// Uses SQLCipher for AES-256 encryption.
class ManualSleepRepository {
  static ManualSleepRepository? _instance;
  static ManualSleepRepository get instance {
    _instance ??= ManualSleepRepository._();
    return _instance!;
  }

  ManualSleepRepository._();

  /// Ensure tables exist
  Future<void> _ensureTablesExist() async {
    final db = await SecureDatabaseManager.instance.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS manual_sleep_entries (
        id TEXT PRIMARY KEY,
        user_email TEXT NOT NULL,
        date TEXT NOT NULL,
        total_sleep_minutes INTEGER NOT NULL,
        sleep_start TEXT,
        sleep_end TEXT,
        sleep_quality_1to5 INTEGER,
        wake_frequency INTEGER,
        rested_feeling_1to5 INTEGER,
        physiological_symptoms TEXT,
        bedtime TEXT,
        wake_time TEXT,
        awakenings INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        source TEXT DEFAULT 'manual',
        is_user_override INTEGER DEFAULT 0,
        UNIQUE(user_email, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sleep_prompt_state (
        user_email TEXT PRIMARY KEY,
        last_confirm_prompt_at TEXT,
        prompt_count_this_week INTEGER DEFAULT 0,
        week_start_date TEXT
      )
    ''');

    print('✅ Manual sleep tables initialized');
  }

  /// Insert or update a manual sleep entry
  /// 
  /// If an entry exists for this user+date, it will be updated.
  /// Returns the entry ID.
  Future<String> upsertManualSleep(ManualSleepEntry entry) async {
    await _ensureTablesExist();
    final db = await SecureDatabaseManager.instance.database;

    // Update timestamp
    final updatedEntry = entry.copyWith(updatedAt: DateTime.now());

    await db.insert(
      'manual_sleep_entries',
      updatedEntry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('💾 Saved manual sleep: ${updatedEntry.date} (${updatedEntry.totalSleepMinutes}min)');
    return updatedEntry.id;
  }

  /// Get manual sleep entry for a specific date
  Future<ManualSleepEntry?> getManualSleep(String userEmail, String date) async {
    await _ensureTablesExist();
    final db = await SecureDatabaseManager.instance.database;

    final results = await db.query(
      'manual_sleep_entries',
      where: 'user_email = ? AND date = ?',
      whereArgs: [userEmail, date],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ManualSleepEntry.fromMap(results.first);
  }

  /// Get all manual sleep entries for a user (for history/trends)
  Future<List<ManualSleepEntry>> getAllManualSleep(String userEmail, {int? limit}) async {
    await _ensureTablesExist();
    final db = await SecureDatabaseManager.instance.database;

    final results = await db.query(
      'manual_sleep_entries',
      where: 'user_email = ?',
      whereArgs: [userEmail],
      orderBy: 'date DESC',
      limit: limit,
    );

    return results.map((map) => ManualSleepEntry.fromMap(map)).toList();
  }

  /// Delete a manual sleep entry
  Future<void> deleteManualSleep(String userEmail, String date) async {
    await _ensureTablesExist();
    final db = await SecureDatabaseManager.instance.database;

    await db.delete(
      'manual_sleep_entries',
      where: 'user_email = ? AND date = ?',
      whereArgs: [userEmail, date],
    );

    print('🗑️ Deleted manual sleep: $date');
  }

  /// Check if we should show confirmation prompt (throttling)
  /// 
  /// Returns true if:
  /// - Less than 2 prompts shown this week
  /// - OR triggered by low-confidence sleep
  Future<bool> shouldShowConfirmPrompt(String userEmail, {bool isLowConfidence = false}) async {
    await _ensureTablesExist();
    
    // Always show prompt for low-confidence sleep
    if (isLowConfidence) return true;

    final db = await SecureDatabaseManager.instance.database;
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final weekStartStr = _formatDate(weekStart);

    final results = await db.query(
      'sleep_prompt_state',
      where: 'user_email = ?',
      whereArgs: [userEmail],
      limit: 1,
    );

    if (results.isEmpty) {
      // First time, allow prompt
      return true;
    }

    final state = results.first;
    final stateWeekStart = state['week_start_date'] as String?;
    final promptCount = state['prompt_count_this_week'] as int? ?? 0;

    // If new week, reset counter
    if (stateWeekStart != weekStartStr) {
      return true;
    }

    // Allow max 2 prompts per week
    return promptCount < 2;
  }

  /// Record that a confirmation prompt was shown
  Future<void> recordConfirmPromptShown(String userEmail) async {
    await _ensureTablesExist();
    final db = await SecureDatabaseManager.instance.database;
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final weekStartStr = _formatDate(weekStart);

    final results = await db.query(
      'sleep_prompt_state',
      where: 'user_email = ?',
      whereArgs: [userEmail],
      limit: 1,
    );

    if (results.isEmpty) {
      // Create new state
      await db.insert('sleep_prompt_state', {
        'user_email': userEmail,
        'last_confirm_prompt_at': now.toIso8601String(),
        'prompt_count_this_week': 1,
        'week_start_date': weekStartStr,
      });
    } else {
      final state = results.first;
      final stateWeekStart = state['week_start_date'] as String?;
      final promptCount = state['prompt_count_this_week'] as int? ?? 0;

      // If new week, reset counter
      final newCount = (stateWeekStart == weekStartStr) ? promptCount + 1 : 1;

      await db.update(
        'sleep_prompt_state',
        {
          'last_confirm_prompt_at': now.toIso8601String(),
          'prompt_count_this_week': newCount,
          'week_start_date': weekStartStr,
        },
        where: 'user_email = ?',
        whereArgs: [userEmail],
      );
    }

    print('📊 Confirmation prompt recorded (count this week: ${results.isEmpty ? 1 : (results.first['week_start_date'] == weekStartStr ? (results.first['prompt_count_this_week'] as int) + 1 : 1)})');
  }

  /// Get Monday of the current week
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // Monday = 1, Sunday = 7
    return date.subtract(Duration(days: weekday - 1));
  }

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
