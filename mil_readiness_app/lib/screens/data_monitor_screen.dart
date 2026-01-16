import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/secure_database_manager.dart';
import '../services/all_scores_calculator.dart';
import '../services/last_sleep_service.dart';
import '../models/user_profile.dart';
import '../routes.dart';

/// Monitoring screen with tabs for real-time data and calculated scores
class DataMonitorScreen extends StatefulWidget {
  final SessionController session;
  
  const DataMonitorScreen({super.key, required this.session});

  @override
  State<DataMonitorScreen> createState() => _DataMonitorScreenState();
}

class _DataMonitorScreenState extends State<DataMonitorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Real-time data
  Map<String, dynamic> _latestMetrics = {};
  LastSleep? _lastSleepSummary;
  DateTime? _lastSync;
  bool _loadingMetrics = true;
  
  // Calculated scores
  Map<String, double> _scores = {};
  bool _loadingScores = true;
  String _overallCategory = 'UNKNOWN';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadLatestMetrics(),
      _loadCalculatedScores(),
    ]);
  }

  Future<void> _loadLatestMetrics() async {
    setState(() => _loadingMetrics = true);
    
    try {
      final db = await SecureDatabaseManager.instance.database;
      final email = widget.session.email;
      
      if (email == null) return;
      
      // Get latest metrics from last 24 hours
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      
      final results = await db.query(
        'health_metrics',
        where: 'user_email = ? AND timestamp >= ?',
        whereArgs: [email, yesterday.millisecondsSinceEpoch],
        orderBy: 'timestamp DESC',
        limit: 1000, // Increased limit to get more data
      );
      
      print('📊 DataMonitor: Found ${results.length} metrics in last 24h');
      
      // Define all metric types we're tracking (from AppleHealthAdapter)
      final allMetricTypes = [
        'HEART_RATE',
        'RESTING_HEART_RATE',
        'WALKING_HEART_RATE',
        'HEART_RATE_VARIABILITY_SDNN',
        'HEART_RATE_VARIABILITY_RMSSD',
        'BLOOD_OXYGEN',
        'RESPIRATORY_RATE',
        'PERIPHERAL_PERFUSION_INDEX',
        'STEPS',
        'DISTANCE_WALKING_RUNNING',
        'DISTANCE_CYCLING',
        'DISTANCE_SWIMMING',
        'FLIGHTS_CLIMBED',
        'ACTIVE_ENERGY_BURNED',
        'EXERCISE_TIME',
        'SLEEP_ASLEEP',
        'SLEEP_DEEP',
        'SLEEP_REM',
        'SLEEP_LIGHT',
        'SLEEP_AWAKE',
        'SLEEP_AWAKE_IN_BED',
        'SLEEP_IN_BED',
        'SLEEP_SESSION',
        'ELECTRODERMAL_ACTIVITY',
        'MINDFULNESS',
        'HIGH_HEART_RATE_EVENT',
        'LOW_HEART_RATE_EVENT',
        'IRREGULAR_HEART_RATE_EVENT',
        'BODY_TEMPERATURE',
        'WORKOUT',
      ];
      
      final Map<String, dynamic> metrics = {};
      
      // Initialize all metrics with null (no data)
      for (var type in allMetricTypes) {
        metrics[type] = {'value': null, 'timestamp': null};
      }
      
      // Populate with actual data where available
      for (var row in results) {
        final type = row['metric_type'] as String;
        
        // Handle value conversion
        final rawValue = row['value'];
        double? value;
        if (rawValue is double) {
          value = rawValue;
        } else if (rawValue is int) {
          value = rawValue.toDouble();
        } else if (rawValue is num) {
          value = rawValue.toDouble();
        }
        
        final timestamp = DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int);
        
        // Keep only the most recent value for each metric type
        if (metrics.containsKey(type) && metrics[type]['value'] == null) {
          metrics[type] = {'value': value, 'timestamp': timestamp};
          print('  📌 $type: ${value ?? "No data"} at ${timestamp.toLocal()}');
        }
      }
      
      print('📊 Total metric types tracked: ${metrics.length}');
      
      // Load LastSleep summary
      LastSleep? lastSleep;
      if (email.isNotEmpty) {
        lastSleep = await LastSleepService.getLastSleep(email);
      }
      
      setState(() {
        _latestMetrics = metrics;
        _lastSleepSummary = lastSleep;
        _lastSync = DateTime.now();
        _loadingMetrics = false;
      });
    } catch (e) {
      print('❌ Error loading metrics: $e');
      setState(() => _loadingMetrics = false);
    }
  }

  Future<void> _loadCalculatedScores() async {
    setState(() => _loadingScores = true);
    
    try {
      final email = widget.session.email;
      if (email == null) return;
      
      final dbManager = SecureDatabaseManager.instance;
      final calculator = AllScoresCalculator(db: dbManager);
      
      // Get user profile - use default if table doesn't exist
      UserProfile profile = UserProfile(
        email: email,
        fullName: 'User',
        age: 30,
        heightCm: 175,
        weightKg: 75,
        gender: 'male',
        targetSleep: 450,
      );
      
      try {
        final db = await dbManager.database;
        final profiles = await db.query(
          'user_profiles',
          where: 'email = ?',
          whereArgs: [email],
        );
        
        if (profiles.isNotEmpty) {
          profile = UserProfile.fromJson(profiles.first);
        }
      } catch (e) {
        print('⚠️ Using default profile (user_profiles table not found)');
      }
      
      final result = await calculator.calculateAll(
        userEmail: email,
        date: DateTime.now(),
        profile: profile,
      );
      
      setState(() {
        _scores = {
          'Overall Readiness': result.overallReadiness,
          'Recovery Score': result.recoveryScore,
          'Fatigue Index': result.fatigueIndex,
          'Endurance Capacity': result.enduranceCapacity,
          'Sleep Index': result.sleepIndex,
          'Cardiovascular Fitness': result.cardiovascularFitness,
          'Stress Load': result.stressLoad,
          'Injury Risk': result.injuryRisk,
          'Cardio-Resp Stability': result.cardioRespStability,
          'Illness Risk': result.illnessRisk,
          'Daily Activity': result.dailyActivity,
          'Work Capacity': result.workCapacity,
          'Altitude Score': result.altitudeScore,
          'Cardiac Safety': result.cardiacSafetyPenalty,
          'Sleep Debt': result.sleepDebt,
          'Training Readiness': result.trainingReadiness,
          'Cognitive Alertness': result.cognitiveAlertness,
          'Thermoregulatory': result.thermoregulatoryAdaptation,
        };
        _overallCategory = result.category;
        _loadingScores = false;
      });
    } catch (e) {
      print('❌ Error calculating scores: $e');
      setState(() => _loadingScores = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Monitor'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.sensors), text: 'Real-Time Data'),
            Tab(icon: Icon(Icons.calculate), text: 'Calculated Scores'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRealTimeTab(),
          _buildCalculatedTab(),
        ],
      ),
    );
  }

  Widget _buildRealTimeTab() {
    if (_loadingMetrics) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_latestMetrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No recent data'),
            const SizedBox(height: 8),
            const Text(
              'LiveSync collects data every 60 seconds',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLatestMetrics,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLatestMetrics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Last sync time
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LiveSync Active',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Last updated: ${DateFormat('h:mm:ss a').format(_lastSync ?? DateTime.now())}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Latest Sleep Summary Card
          if (_lastSleepSummary != null)
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Sleep Session',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _lastSleepSummary!.confidence.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Sleep', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              _lastSleepSummary!.formattedDuration,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Efficiency', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              '${(_lastSleepSummary!.sleepEfficiency * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Stage Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStageLabel('Deep', _lastSleepSummary!.deepMinutes, Colors.blue),
                          const SizedBox(width: 8),
                          _buildStageLabel('REM', _lastSleepSummary!.remMinutes, Colors.purple),
                          const SizedBox(width: 8),
                          _buildStageLabel('Light', _lastSleepSummary!.lightMinutes, Colors.cyan),
                          const SizedBox(width: 8),
                          _buildStageLabel('Awake', _lastSleepSummary!.awakeMinutes, Colors.orange),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (_lastSleepSummary != null) const SizedBox(height: 16),
          
          // Metrics grid
          ..._latestMetrics.entries.map((entry) {
            final data = entry.value as Map<String, dynamic>;
            final value = data['value'] as double?;
            final timestamp = data['timestamp'] as DateTime?;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: _getMetricIcon(entry.key),
                title: Text(
                  _formatMetricName(entry.key),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  timestamp != null 
                    ? 'Updated ${_formatTimestamp(timestamp)}'
                    : 'No data yet',
                  style: TextStyle(
                    fontSize: 11,
                    color: timestamp != null ? Colors.grey : Colors.orange,
                  ),
                ),
                trailing: Text(
                  value != null ? _formatMetricValue(entry.key, value) : '--',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: value != null ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCalculatedTab() {
    if (_loadingScores) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_scores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No scores calculated yet'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCalculatedScores,
              icon: const Icon(Icons.calculate),
              label: const Text('Calculate Scores'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCalculatedScores,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overall category banner
          Card(
            color: _getCategoryColor(_overallCategory),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _overallCategory,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Overall Readiness: ${_scores['Overall Readiness']?.toStringAsFixed(1) ?? 'N/A'}',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // All scores
          ..._scores.entries.map((entry) {
            final score = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getScoreColor(score),
                  child: Text(
                    score.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(entry.key),
                trailing: _buildScoreBar(score),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildScoreBar(double score) {
    return SizedBox(
      width: 100,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: score / 100,
          minHeight: 8,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(_getScoreColor(score)),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'GO':
        return Colors.green;
      case 'CAUTION':
        return Colors.orange;
      case 'LIMITED':
        return Colors.deepOrange;
      case 'STOP':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Icon _getMetricIcon(String type) {
    if (type.contains('HEART')) return const Icon(Icons.favorite, color: Colors.red);
    if (type.contains('HRV')) return const Icon(Icons.show_chart, color: Colors.purple);
    if (type.contains('SLEEP')) return const Icon(Icons.bedtime, color: Colors.indigo);
    if (type.contains('OXYGEN')) return const Icon(Icons.air, color: Colors.blue);
    if (type.contains('RESPIRATORY')) return const Icon(Icons.air, color: Colors.cyan);
    if (type.contains('STEPS')) return const Icon(Icons.directions_walk, color: Colors.green);
    if (type.contains('ENERGY')) return const Icon(Icons.flash_on, color: Colors.amber);
    return const Icon(Icons.analytics, color: Colors.grey);
  }

  String _formatMetricName(String type) {
    return type.replaceAll('_', ' ').toLowerCase().split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatMetricValue(String type, double value) {
    if (type.contains('HEART_RATE')) return '${value.toStringAsFixed(0)} bpm';
    if (type.contains('HRV')) return '${value.toStringAsFixed(0)} ms';
    if (type.contains('OXYGEN')) return '${value.toStringAsFixed(1)}%';
    if (type.contains('RESPIRATORY')) return '${value.toStringAsFixed(0)} /min';
    if (type.contains('STEPS')) return value.toStringAsFixed(0);
    if (type.contains('ENERGY')) return '${value.toStringAsFixed(0)} kcal';
    if (type.contains('SLEEP')) {
      // Individual segments are in minutes. 
      // If it's the total session, show hours, otherwise keep as minutes for clarity in raw logs
      if (type == 'SLEEP_SESSION') {
        return '${(value / 60).toStringAsFixed(1)} hrs';
      }
      return '${value.toStringAsFixed(0)} min';
    }
    return value.toStringAsFixed(1);
  }

  Widget _buildStageLabel(String label, int minutes, Color color) {
    if (minutes == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: ${minutes}m',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('h:mm a').format(timestamp);
  }
}
