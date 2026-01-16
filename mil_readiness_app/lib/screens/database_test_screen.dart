import 'package:flutter/material.dart';
import '../database/health_data_repository.dart';
import '../database/secure_database_manager.dart';
import '../routes.dart';
import '../services/local_secure_store.dart';

/// Database test and verification screen
/// Shows encrypted metrics, database stats, and testing tools
class DatabaseTestScreen extends StatefulWidget {
  const DatabaseTestScreen({super.key});

  @override
  State<DatabaseTestScreen> createState() => _DatabaseTestScreenState();
}

class _DatabaseTestScreenState extends State<DatabaseTestScreen> {
  bool _loading = true;
  int _totalMetrics = 0;
  List<String> _metricTypes = [];
  Map<String, dynamic>? _dbStats;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      // Get actual user email from session
      _email = await LocalSecureStore.instance.getActiveSessionEmail();
      
      if (_email == null || _email!.isEmpty) {
        print('⚠️ No active session email found');
        setState(() => _loading = false);
        return;
      }
      
      // Get metrics count
      _totalMetrics = await HealthDataRepository.countUserMetrics(_email!);
      
      // Get available metric types
      _metricTypes = await HealthDataRepository.getAvailableMetricTypes(_email!);
      
      // Get database stats
      _dbStats = await SecureDatabaseManager.getStats();
      
      setState(() => _loading = false);
    } catch (e) {
      print('Error loading database stats: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Database Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCard(),
                  const SizedBox(height: 16),
                  _buildMetricTypesCard(),
                  const SizedBox(height: 16),
                  _buildDatabaseStatsCard(),
                  const SizedBox(height: 16),
                  _buildActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storage, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Database Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _statRow('User Email', _email ?? 'Unknown'),
            _statRow('Total Metrics Stored', '$_totalMetrics'),
            _statRow('Unique Metric Types', '${_metricTypes.length}'),
            _statRow('Encryption', 'AES-256 (Active)'),
            _statRow('Auto-Delete', '30 days'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTypesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.list, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Collected Metric Types',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (_metricTypes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No metrics collected yet. Wait for live sync to run.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._metricTypes.map((type) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(type)),
                        FutureBuilder<Map<String, dynamic>>(
                          future: HealthDataRepository.getMetricStats(
                            _email!,
                            type,
                            window: const Duration(days: 7),
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            final count = snapshot.data!['count'] ?? 0;
                            return Text(
                              '$count points',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseStatsCard() {
    if (_dbStats == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Database Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _statRow('Database Size', '${_dbStats!['size_mb']} MB'),
            _statRow('Total Records', '${_dbStats!['total_metrics']}'),
            if (_dbStats!['oldest_date'] != null)
              _statRow('Oldest Record', _formatDate(_dbStats!['oldest_date'])),
            if (_dbStats!['newest_date'] != null)
              _statRow('Newest Record', _formatDate(_dbStats!['newest_date'])),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Database Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final deleted = await HealthDataRepository.deleteOldMetrics(
                    retention: const Duration(days: 30),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted $deleted old records')),
                    );
                    await _loadData();
                  }
                },
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Run Auto-Cleanup (30+ days)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final db = await SecureDatabaseManager.instance.database;
                  try {
                    final result = await db.rawQuery('PRAGMA integrity_check');
                    final integrity = result.isNotEmpty && 
                        result.first.values.first == 'ok';
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            integrity
                                ? '✅ Database integrity verified'
                                : '🚨 Database integrity check FAILED',
                          ),
                          backgroundColor: integrity ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Integrity check error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.verified_user),
                label: const Text('Verify Database Integrity'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
