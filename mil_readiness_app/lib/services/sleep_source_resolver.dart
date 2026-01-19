import '../services/last_sleep_service.dart';
import '../repositories/manual_sleep_repository.dart';
import '../models/manual_sleep_entry.dart';
import '../database/secure_database_manager.dart';

/// Result of sleep source resolution
class ResolvedSleep {
  final int minutes;
  final String source; // 'auto', 'manual', or 'none'
  final String confidence; // 'high', 'medium', 'low'
  final bool isOverride; // True if manual sleep overrode auto
  final DateTime? sleepStart;
  final DateTime? sleepEnd;
  final LastSleep? autoSleepData;
  final ManualSleepEntry? manualSleepData;

  ResolvedSleep({
    required this.minutes,
    required this.source,
    required this.confidence,
    this.isOverride = false,
    this.sleepStart,
    this.sleepEnd,
    this.autoSleepData,
    this.manualSleepData,
  });

  /// Check if sleep is low-confidence (triggers prompt)
  bool get isLowConfidence {
    if (source == 'none') return true;
    if (confidence == 'low') return true;
    if (minutes < 210 || minutes > 660) return true; // <3.5h or >11h
    return false;
  }

  /// Check if sleep is missing entirely
  bool get isMissing => source == 'none' || minutes == 0;

  @override
  String toString() {
    return 'ResolvedSleep(source: $source, minutes: $minutes, confidence: $confidence, override: $isOverride)';
  }
}

/// Service to resolve which sleep source to use for readiness calculations
/// 
/// Decision logic:
/// 1. If manual exists AND isUserOverride=true → use manual
/// 2. Else if auto exists → use auto
/// 3. Else if manual exists → use manual
/// 4. Else → return 'none' (graceful degradation)
class SleepSourceResolver {
  /// Get resolved sleep for a specific date
  /// 
  /// [date] should be the WAKE-UP DAY in YYYY-MM-DD format (matches LastSleepService convention)
  /// Example: Sleep from Jan 17 10pm → Jan 18 6am, pass date = "2026-01-18"
  static Future<ResolvedSleep> getSleepForDate(String userEmail, String date) async {
    print('🔍 Resolving sleep source for $date...');

    // Fetch manual sleep from repository
    final manualSleep = await ManualSleepRepository.instance.getManualSleep(userEmail, date);

    // Fetch auto sleep directly from database (AVOID calling LastSleepService to prevent circular dependency)
    final autoSleepMinutes = await _getAutoSleepMinutes(userEmail);
    
    // Create simplified auto sleep representation
    final bool hasAutoSleep = autoSleepMinutes > 0;
    
    // Decision logic
    if (manualSleep != null && manualSleep.isUserOverride) {
      // User explicitly wants manual to override
      print('  ✅ Using MANUAL sleep (user override): ${manualSleep.totalSleepMinutes}min');
      return ResolvedSleep(
        minutes: manualSleep.totalSleepMinutes,
        source: 'manual',
        confidence: _deriveConfidence(manualSleep.totalSleepMinutes, hasAutoData: hasAutoSleep),
        isOverride: true,
        sleepStart: manualSleep.sleepStart,
        sleepEnd: manualSleep.sleepEnd,
        autoSleepData: null,
        manualSleepData: manualSleep,
      );
    }

    if (hasAutoSleep) {
      // Use auto sleep (preferred when available)
      print('  ✅ Using AUTO sleep: ${autoSleepMinutes}min');
      return ResolvedSleep(
        minutes: autoSleepMinutes,
        source: 'auto',
        confidence: autoSleepMinutes >= 180 ? 'medium' : 'low',
        isOverride: false,
        sleepStart: null,
        sleepEnd: null,
        autoSleepData: null, // Don't need full LastSleep object here
        manualSleepData: manualSleep,
      );
    }

    if (manualSleep != null) {
      // Fallback to manual (auto not available)
      print('  ✅ Using MANUAL sleep (auto unavailable): ${manualSleep.totalSleepMinutes}min');
      return ResolvedSleep(
        minutes: manualSleep.totalSleepMinutes,
        source: 'manual',
        confidence: _deriveConfidence(manualSleep.totalSleepMinutes, hasAutoData: false),
        isOverride: false,
        sleepStart: manualSleep.sleepStart,
        sleepEnd: manualSleep.sleepEnd,
        autoSleepData: null,
        manualSleepData: manualSleep,
      );
    }

    // No sleep data available
    print('  ⚠️ No sleep data available for $date');
    return ResolvedSleep(
      minutes: 0,
      source: 'none',
      confidence: 'low',
      isOverride: false,
      autoSleepData: null,
      manualSleepData: null,
    );
  }

  /// Get auto sleep minutes directly from database (avoids calling LastSleepService)
  static Future<int> _getAutoSleepMinutes(String userEmail) async {
    try {
      final db = await SecureDatabaseManager.instance.database;
      
      // Get latest sleep session total minutes
      final result = await db.rawQuery('''
        SELECT value FROM health_metrics
        WHERE user_email = ?
          AND metric_type IN ('SLEEP_ASLEEP', 'SLEEP_SESSION')
          AND is_interval = 1
        ORDER BY date_to DESC
        LIMIT 1
      ''', [userEmail]);
      
      if (result.isEmpty) return 0;
      return (result.first['value'] as num).toInt();
    } catch (e) {
      print('  ⚠️ Error fetching auto sleep: $e');
      return 0;
    }
  }

  /// Get today's wake-up date in YYYY-MM-DD format
  /// 
  /// This is the date that should be used when querying/saving manual sleep for "last night"
  static String getTodayWakeDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Derive confidence level for manual sleep
  static String _deriveConfidence(int minutes, {required bool hasAutoData}) {
    // Very low or very high sleep is suspicious
    if (minutes < 180 || minutes > 720) return 'low';

    // If we have auto data to compare against, confidence is higher
    if (hasAutoData) return 'medium';

    // Manual-only, reasonable range
    if (minutes >= 360 && minutes <= 540) return 'medium'; // 6-9h
    return 'low';
  }

  /// Check if manual entry is needed (for UI prompting)
  /// 
  /// Returns true if:
  /// - Auto sleep is missing
  /// - Auto sleep is low-confidence
  /// - Auto sleep is suspiciously short/long
  static Future<bool> isManualEntryNeeded(String userEmail, String date) async {
    final resolved = await getSleepForDate(userEmail, date);
    return resolved.isLowConfidence || resolved.isMissing;
  }
}
