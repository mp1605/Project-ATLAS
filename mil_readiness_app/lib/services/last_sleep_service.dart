import '../database/secure_database_manager.dart';

/// Service for querying the most recent complete sleep session
/// and aggregating sleep stages correctly
class LastSleep {
  final DateTime bedtime;
  final DateTime wakeTime;
  final int totalMinutes;
  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;
  final int inBedMinutes;
  final double sleepEfficiency;
  final String confidence; // 'high' | 'medium' | 'low'
  
  LastSleep({
    required this.bedtime,
    required this.wakeTime,
    required this.totalMinutes,
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
    required this.inBedMinutes,
    required this.sleepEfficiency,
    required this.confidence,
  });
  
  /// Format total sleep duration as "7h 15m"
  String get formattedDuration {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }
  
  /// Format time as "10:30 PM"
  String formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class LastSleepService {
  /// Get the most recent complete sleep session
  /// 
  /// Strategy:
  /// 1. Find latest SLEEP_SESSION or SLEEP_IN_BED (defines sleep window)
  /// 2. Aggregate all sleep stages within that window
  /// 3. Calculate sleep efficiency and confidence
  static Future<LastSleep?> getLastSleep(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    print('💤 LastSleepService: Finding latest sleep session for $userEmail...');
    
    // Step 1: Find the latest sleep window
    final sessionResult = await db.rawQuery('''
      SELECT date_from, date_to, value FROM health_metrics
      WHERE user_email = ?
        AND metric_type IN ('SLEEP_SESSION', 'SLEEP_IN_BED')
        AND is_interval = 1
      ORDER BY date_to DESC
      LIMIT 1
    ''', [userEmail]);
    
    DateTime windowStart, windowEnd;
    int inBedMinutes = 0;
    
    if (sessionResult.isNotEmpty) {
      // Use session boundaries
      windowStart = DateTime.parse(sessionResult.first['date_from'] as String);
      windowEnd = DateTime.parse(sessionResult.first['date_to'] as String);
      inBedMinutes = (sessionResult.first['value'] as num).toInt();
      
      print('  ✅ Found sleep session: ${windowStart.toLocal()} → ${windowEnd.toLocal()}');
    } else {
      // Fallback: find most recent sleep stage end time
      final latestSegment = await db.rawQuery('''
        SELECT MAX(date_to) as latest_end FROM health_metrics
        WHERE user_email = ?
          AND metric_type IN ('SLEEP_DEEP', 'SLEEP_REM', 'SLEEP_LIGHT', 'SLEEP_AWAKE')
          AND is_interval = 1
      ''', [userEmail]);
      
      if (latestSegment.isEmpty || latestSegment.first['latest_end'] == null) {
        print('  ⚠️ No sleep data found');
        return null; // No sleep data
      }
      
      windowEnd = DateTime.parse(latestSegment.first['latest_end'] as String);
      windowStart = windowEnd.subtract(const Duration(hours: 14)); // Max sleep window
      
      print('  ⚠️ No session found, using estimated window: ${windowStart.toLocal()} → ${windowEnd.toLocal()}');
    }
    
    // Step 2: Aggregate sleep stages within the window
    final stages = await db.rawQuery('''
      SELECT metric_type, SUM(value) as total_minutes
      FROM health_metrics
      WHERE user_email = ?
        AND metric_type IN ('SLEEP_DEEP', 'SLEEP_REM', 'SLEEP_LIGHT', 'SLEEP_AWAKE')
        AND is_interval = 1
        AND date_from >= ?
        AND date_to <= ?
      GROUP BY metric_type
    ''', [userEmail, windowStart.toIso8601String(), windowEnd.toIso8601String()]);
    
    int deep = 0, rem = 0, light = 0, awake = 0;
    for (var row in stages) {
      final type = row['metric_type'] as String;
      final mins = (row['total_minutes'] as num).toInt();
      
      if (type == 'SLEEP_DEEP') deep = mins;
      else if (type == 'SLEEP_REM') rem = mins;
      else if (type == 'SLEEP_LIGHT') light = mins;
      else if (type == 'SLEEP_AWAKE') awake = mins;
    }
    
    final asleep = deep + rem + light;
    
    // If no in-bed data, estimate from stages
    if (inBedMinutes == 0) {
      inBedMinutes = asleep + awake;
    }
    
    final efficiency = inBedMinutes > 0 ? (asleep / inBedMinutes) : 0.0;
    
    // Step 3: Determine confidence
    String confidence;
    if (sessionResult.isNotEmpty && deep > 0 && rem > 0) {
      confidence = 'high'; // Has session + all stages
    } else if (asleep >= 180) { // At least 3 hours
      confidence = 'medium';
    } else {
      confidence = 'low';
    }
    
    print('  📊 Sleep stages: Deep=${deep}m, REM=${rem}m, Light=${light}m, Awake=${awake}m');
    print('  📊 Total asleep: ${asleep}m, Efficiency: ${(efficiency * 100).toStringAsFixed(1)}%, Confidence: $confidence');
    
    if (asleep == 0) {
      print('  ⚠️ No sleep time recorded in this session');
      return null;
    }
    
    return LastSleep(
      bedtime: windowStart,
      wakeTime: windowEnd,
      totalMinutes: asleep,
      deepMinutes: deep,
      remMinutes: rem,
      lightMinutes: light,
      awakeMinutes: awake,
      inBedMinutes: inBedMinutes,
      sleepEfficiency: efficiency,
      confidence: confidence,
    );
  }
}
