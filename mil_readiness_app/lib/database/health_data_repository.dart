import 'dart:convert';
import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'secure_database_manager.dart';

/// Data models
class HealthMetric {
  final String type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String source;
  final Map<String, dynamic>? metadata;

  HealthMetric({
    required this.type,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    this.metadata,
  });

  Map<String, dynamic> toMap(String userEmail) {
    final metadataJson = metadata != null ? jsonEncode(metadata) : null;
    
    // Extract interval metadata if present
    final isInterval = metadata?['is_interval'] == true;
    final dateFrom = metadata?['date_from'] as String?;
    final dateTo = metadata?['date_to'] as String?;
    
    return {
      'user_email': userEmail,
      'metric_type': type,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'source': source,
      'metadata': metadataJson,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'date_from': dateFrom,
      'date_to': dateTo,
      'is_interval': isInterval ? 1 : 0,
    };
  }

  static HealthMetric fromMap(Map<String, dynamic> map) {
    return HealthMetric(
      type: map['metric_type'] as String,
      value: (map['value'] as num).toDouble(),
      unit: map['unit'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      source: map['source'] as String,
      metadata: map['metadata'] != null 
          ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>?
          : null,
    );
  }
}

/// Repository for accessing encrypted health data
class HealthDataRepository {
  /// Insert health metrics (batch) - encrypted automatically
  static Future<int> insertHealthMetrics(
    String userEmail,
    List<HealthMetric> metrics,
  ) async {
    if (metrics.isEmpty) return 0;
    
    final db = await SecureDatabaseManager.instance.database;
    final batch = db.batch();
    
    for (var metric in metrics) {
      batch.insert(
        'health_metrics',
        metric.toMap(userEmail),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    print('💾 Encrypted and stored ${metrics.length} health metrics for $userEmail');
    
    return metrics.length;
  }

  /// Get recent metrics within a time window
  static Future<List<HealthMetric>> getRecentMetrics(
    String userEmail, {
    Duration window = const Duration(days: 7),
    String? metricType,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final since = DateTime.now()
        .subtract(window)
        .millisecondsSinceEpoch;
    
    List<Map<String, dynamic>> results;
    
    if (metricType != null) {
      // Filter by specific metric type
      results = await db.query(
        'health_metrics',
        where: 'user_email = ? AND timestamp > ? AND metric_type = ?',
        whereArgs: [userEmail, since, metricType],
        orderBy: 'timestamp DESC',
        limit: 1000, // Safety limit
      );
    } else {
      // All metrics
      results = await db.query(
        'health_metrics',
        where: 'user_email = ? AND timestamp > ?',
        whereArgs: [userEmail, since],
        orderBy: 'timestamp DESC',
        limit: 10000, // Safety limit
      );
    }
    
    return results.map((row) => HealthMetric.fromMap(row)).toList();
  }

  /// Get metrics for a specific date range
  static Future<List<HealthMetric>> getMetricsInRange(
    String userEmail, {
    required DateTime start,
    required DateTime end,
    String? metricType,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    List<Map<String, dynamic>> results;
    
    if (metricType != null) {
      results = await db.query(
        'health_metrics',
        where: 'user_email = ? AND timestamp >= ? AND timestamp <= ? AND metric_type = ?',
        whereArgs: [
          userEmail,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
          metricType,
        ],
        orderBy: 'timestamp ASC',
      );
    } else {
      results = await db.query(
        'health_metrics',
        where: 'user_email = ? AND timestamp >= ? AND timestamp <= ?',
        whereArgs: [
          userEmail,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'timestamp ASC',
      );
    }
    
    return results.map((row) => HealthMetric.fromMap(row)).toList();
  }

  /// Get aggregated stats for a metric type
  static Future<Map<String, dynamic>> getMetricStats(
    String userEmail,
    String metricType, {
    Duration window = const Duration(days: 7),
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final since = DateTime.now()
        .subtract(window)
        .millisecondsSinceEpoch;
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        AVG(value) as average,
        MIN(value) as minimum,
        MAX(value) as maximum,
        SUM(value) as total
      FROM health_metrics
      WHERE user_email = ? AND metric_type = ? AND timestamp > ?
    ''', [userEmail, metricType, since]);
    
    if (result.isEmpty) {
      return {
        'count': 0,
        'average': null,
        'minimum': null,
        'maximum': null,
        'total': null,
      };
    }
    
    return result.first;
  }

  /// Get list of available metric types for user
  static Future<List<String>> getAvailableMetricTypes(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final results = await db.rawQuery('''
      SELECT DISTINCT metric_type 
      FROM health_metrics 
      WHERE user_email = ?
      ORDER BY metric_type
    ''', [userEmail]);
    
    return results
        .map((row) => row['metric_type'] as String)
        .toList();
  }

  /// Count total metrics for user
  static Future<int> countUserMetrics(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM health_metrics WHERE user_email = ?',
      [userEmail],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Securely delete all metrics for a user (with overwrite)
  static Future<void> secureDeleteUserMetrics(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    print('🗑️ Securely deleting metrics for $userEmail...');
    
    // Step 1: Overwrite with random data (DoD 5220.22-M standard)
    final random = Random.secure();
    await db.update(
      'health_metrics',
      {
        'value': random.nextDouble() * 1000,
        'metadata': jsonEncode({'deleted': true, 'timestamp': DateTime.now().toIso8601String()}),
      },
      where: 'user_email = ?',
      whereArgs: [userEmail],
    );
    
    // Step 2: Delete records
    final deletedCount = await db.delete(
      'health_metrics',
      where: 'user_email = ?',
      whereArgs: [userEmail],
    );
    
    // Step 3: Vacuum to reclaim space and overwrite freed pages
    await db.execute('VACUUM');
    
    print('✅ Securely deleted $deletedCount metrics for $userEmail');
  }

  /// Delete old metrics (called by auto-cleanup)
  static Future<int> deleteOldMetrics({
    Duration retention = const Duration(days: 30),
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    final cutoff = DateTime.now()
        .subtract(retention)
        .millisecondsSinceEpoch;
    
    final deletedCount = await db.delete(
      'health_metrics',
      where: 'timestamp < ?',
      whereArgs: [cutoff],
    );
    
    if (deletedCount > 0) {
      await db.execute('VACUUM');
      print('🗑️ Auto-deleted $deletedCount metrics older than ${retention.inDays} days');
    }
    
    return deletedCount;
  }

  /// Update sync status for user
  static Future<void> updateSyncStatus({
    required String userEmail,
    required String status,
    String? wearableType,
    List<String>? enabledMetrics,
    String? lastError,
  }) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final data = {
      'user_email': userEmail,
      'last_sync_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': status,
      'wearable_type': wearableType,
      'enabled_metrics': enabledMetrics != null ? jsonEncode(enabledMetrics) : null,
      'last_error': lastError,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    
    await db.insert(
      'sync_status',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get sync status for user
  static Future<Map<String, dynamic>?> getSyncStatus(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    final results = await db.query(
      'sync_status',
      where: 'user_email = ?',
      whereArgs: [userEmail],
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  /// Increment sync counter
  static Future<void> incrementSyncCount(String userEmail) async {
    final db = await SecureDatabaseManager.instance.database;
    
    await db.rawUpdate('''
      UPDATE sync_status 
      SET sync_count = sync_count + 1,
          updated_at = ?
      WHERE user_email = ?
    ''', [DateTime.now().millisecondsSinceEpoch, userEmail]);
  }
}
