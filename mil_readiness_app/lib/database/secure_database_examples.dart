import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../database/secure_database_manager.dart';
import '../database/health_data_repository.dart';

/// Example usage of the secure database system
/// 
/// This demonstrates:
/// - Initializing the encrypted database
/// - Storing health metrics securely
/// - Querying encrypted data
/// - Viewing database statistics
/// - Secure data deletion
class SecureDatabaseExample {
  
  /// Example 1: Initialize database and store health data
  static Future<void> exampleStoreHealthData() async {
    print('\n━━━━ Example 1: Store Health Data ━━━━');
    
    // Database initializes automatically with encryption
    final userEmail = 'soldier@military.com';
    
    // Sample health metrics from wearable
    final metrics = [
      HealthMetric(
        type: 'HEART_RATE',
        value: 72.0,
        unit: 'bpm',
        timestamp: DateTime.now(),
        source: 'apple_watch',
        metadata: {'workout': false, 'resting': true},
      ),
      HealthMetric(
        type: 'STEPS',
        value: 8523.0,
        unit: 'count',
        timestamp: DateTime.now(),
        source: 'apple_watch',
      ),
      HealthMetric(
        type: 'ACTIVE_ENERGY_BURNED',
        value: 425.5,
        unit: 'kcal',
        timestamp: DateTime.now(),
        source: 'apple_watch',
      ),
    ];
    
    // Store in encrypted database (automatic encryption)
    await HealthDataRepository.insertHealthMetrics(userEmail, metrics);
  }

  /// Example 2: Query recent health data
  static Future<void> exampleQueryHealthData() async {
    print('\n━━━━ Example 2: Query Health Data ━━━━');
    
    final userEmail = 'soldier@military.com';
    
    // Get last 7 days of data
    final recentMetrics = await HealthDataRepository.getRecentMetrics(
      userEmail,
      window: const Duration(days: 7),
    );
    
    print('📊 Found ${recentMetrics.length} recent metrics');
    for (var metric in recentMetrics.take(5)) {
      print('  - ${metric.type}: ${metric.value} ${metric.unit} (${metric.timestamp})');
    }
    
    // Get specific metric type
    final heartRateData = await HealthDataRepository.getRecentMetrics(
      userEmail,
      window: const Duration(days: 1),
      metricType: 'HEART_RATE',
    );
    
    print('\n❤️ Found ${heartRateData.length} heart rate measurements today');
  }

  /// Example 3: Get statistics
  static Future<void> exampleGetStatistics() async {
    print('\n━━━━ Example 3: Statistics ━━━━');
    
    final userEmail = 'soldier@military.com';
    
    // Get stats for heart rate
    final stats = await HealthDataRepository.getMetricStats(
      userEmail,
      'HEART_RATE',
      window: const Duration(days: 7),
    );
    
    print('📈 Heart Rate Statistics (7 days):');
    print('  Count: ${stats['count']}');
    print('  Average: ${stats['average']?.toStringAsFixed(1)} bpm');
    print('  Min: ${stats['minimum']?.toStringAsFixed(1)} bpm');
    print('  Max: ${stats['maximum']?.toStringAsFixed(1)} bpm');
    
    // Get database stats
    final dbStats = await SecureDatabaseManager.getStats();
    print('\n💾 Database Statistics:');
    print('  Total Metrics: ${dbStats['total_metrics']}');
    print('  Size: ${dbStats['size_mb']} MB');
    print('  Oldest: ${dbStats['oldest_date']}');
    print('  Newest: ${dbStats['newest_date']}');
  }

  /// Example 4: Secure deletion
  static Future<void> exampleSecureDeletion() async {
    print('\n━━━━ Example 4: Secure Deletion ━━━━');
    
    final userEmail = 'soldier@military.com';
    
    // Securely delete user's data (with overwrite)
    await HealthDataRepository.secureDeleteUserMetrics(userEmail);
    
    print('✅ User data securely deleted');
  }

  /// Example 5: Auto-cleanup
  static Future<void> exampleAutoCleanup() async {
    print('\n━━━━ Example 5: Auto-Cleanup ━━━━');
    
    // Delete metrics older than 30 days
    final deletedCount = await HealthDataRepository.deleteOldMetrics(
      retention: const Duration(days: 30),
    );
    
    print('🗑️ Auto-deleted $deletedCount old metrics');
  }
}

/// Widget to display database statistics
class DatabaseStatsWidget extends StatefulWidget {
  const DatabaseStatsWidget({super.key});

  @override
  State<DatabaseStatsWidget> createState() => _DatabaseStatsWidgetState();
}

class _DatabaseStatsWidgetState extends State<DatabaseStatsWidget> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await SecureDatabaseManager.getStats();
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Encrypted Database',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _statRow('Total Metrics', '${_stats!['total_metrics']}'),
            _statRow('Storage Size', '${_stats!['size_mb']} MB'),
            _statRow('Encrypted', 'AES-256 (Military-grade)'),
            _statRow('Auto-Delete', '30 days'),
            if (_stats!['newest_date'] != null)
              _statRow('Last Updated', _stats!['newest_date']),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadStats,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await HealthDataRepository.deleteOldMetrics();
                      await _loadStats();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Auto-cleanup complete')),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text('Cleanup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
