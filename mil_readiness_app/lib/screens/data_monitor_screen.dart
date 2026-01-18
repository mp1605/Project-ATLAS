import 'dart:math' as math;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/last_sleep_service.dart';
import '../database/secure_database_manager.dart';
import '../services/all_scores_calculator.dart';
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
  Map<String, String> _confidenceLevels = {};
  Map<String, Map<String, dynamic>> _componentBreakdowns = {};
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
      
      // Get latest metrics from last 7 days (to match deep sync history)
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final results = await db.query(
        'health_metrics',
        where: 'user_email = ? AND timestamp >= ?',
        whereArgs: [email, sevenDaysAgo.millisecondsSinceEpoch],
        orderBy: 'timestamp DESC',
        limit: 2000, 
      );
      
      print('📊 DataMonitor: Found ${results.length} metrics in last 7 days');
      
      // Define all metric types we're tracking - Core readiness metrics only
      // Total: 35 metrics (Tier 1 + Tier 2)
      final allMetricTypes = [
        // Cardiovascular
        'HEART_RATE',
        'RESTING_HEART_RATE',
        'HEART_RATE_VARIABILITY_SDNN',
        'HEART_RATE_VARIABILITY_RMSSD',
        'BLOOD_OXYGEN',
        'RESPIRATORY_RATE',
        'BODY_TEMPERATURE',
        // Heart Events
        'HIGH_HEART_RATE_EVENT',
        'LOW_HEART_RATE_EVENT',
        'IRREGULAR_HEART_RATE_EVENT',
        'BLOOD_PRESSURE_SYSTOLIC',
        'BLOOD_PRESSURE_DIASTOLIC',
        // Sleep
        'SLEEP_ASLEEP',
        'SLEEP_DEEP',
        'SLEEP_REM',
        'SLEEP_LIGHT',
        'SLEEP_AWAKE',
        'SLEEP_AWAKE_IN_BED',
        'SLEEP_IN_BED',
        'SLEEP_SESSION',
        // Activity & Load
        'ACTIVE_ENERGY_BURNED',
        'BASAL_ENERGY_BURNED',
        'EXERCISE_TIME',
        'WORKOUT',
        'STEPS',
        'DISTANCE_WALKING_RUNNING',
        'DISTANCE_CYCLING',
        'DISTANCE_SWIMMING',
        'FLIGHTS_CLIMBED',
        // Body & Stress
        'WEIGHT',
        'HEIGHT',
        'BODY_MASS_INDEX',
        'BODY_FAT_PERCENTAGE',
        'LEAN_BODY_MASS',
        'ELECTRODERMAL_ACTIVITY',
        'MINDFULNESS',
      ];
      
      final Map<String, dynamic> metrics = {};
      
      // Initialize all metrics with null (no data)
      for (var type in allMetricTypes) {
        metrics[type] = {'value': null, 'timestamp': null};
      }
      
      // Get last sleep session for sleep metrics
      final lastSleep = await LastSleepService.getLastSleep(email);
      
      // Populate sleep metrics from LastSleepService
      if (lastSleep != null) {
        metrics['SLEEP_ASLEEP'] = {
          'value': lastSleep.totalMinutes.toDouble(),
          'timestamp': lastSleep.wakeTime,
        };
        metrics['SLEEP_DEEP'] = {
          'value': lastSleep.deepMinutes.toDouble(),
          'timestamp': lastSleep.wakeTime,
        };
        metrics['SLEEP_REM'] = {
          'value': lastSleep.remMinutes.toDouble(),
          'timestamp': lastSleep.wakeTime,
        };
        metrics['SLEEP_LIGHT'] = {
          'value': lastSleep.lightMinutes.toDouble(),
          'timestamp': lastSleep.wakeTime,
        };
        metrics['SLEEP_AWAKE'] = {
          'value': lastSleep.awakeMinutes.toDouble(),
          'timestamp': lastSleep.wakeTime,
        };
        metrics['SLEEP_IN_BED'] = {
          'value': lastSleep.inBedMinutes.toDouble(),
          'timestamp': lastSleep.wakeTime,
        };
      }
      
      // For non-sleep interval metrics (mindfulness, workouts, energy), sum for today
      final startOfToday = DateTime(now.year, now.month, now.day);
      final nonSleepIntervalTypes = allMetricTypes.where((type) => 
        _isIntervalType(type) && !type.startsWith('SLEEP_')
      ).toList();
      
      for (var type in nonSleepIntervalTypes) {
        final sumResult = await db.rawQuery('''
          SELECT SUM(value) as total, MAX(timestamp) as latest 
          FROM health_metrics 
          WHERE metric_type = ? AND user_email = ? AND timestamp >= ?
        ''', [type, email, startOfToday.millisecondsSinceEpoch]);
        
        if (sumResult.isNotEmpty && sumResult.first['total'] != null) {
          metrics[type] = {
            'value': (sumResult.first['total'] as num).toDouble(),
            'timestamp': DateTime.fromMillisecondsSinceEpoch(sumResult.first['latest'] as int),
          };
        }
      }
      
      // For point metrics, get the latest value
      final pointTypes = allMetricTypes.where((type) => !_isIntervalType(type)).toList();
      
      for (var type in pointTypes) {
        final latestResult = await db.query(
          'health_metrics',
          where: 'metric_type = ? AND user_email = ?',
          whereArgs: [type, email],
          orderBy: 'timestamp DESC',
          limit: 1,
        );
        
        if (latestResult.isNotEmpty) {
          metrics[type] = {
            'value': (latestResult.first['value'] as num).toDouble(),
            'timestamp': DateTime.fromMillisecondsSinceEpoch(latestResult.first['timestamp'] as int),
          };
        }
      }
      
      
      // BACKFILL LOGIC: If SLEEP_ASLEEP is missing but we have stage data, sum them up
      if (metrics['SLEEP_ASLEEP']['value'] == null && lastSleep != null) {
        final totalAsleep = lastSleep.totalMinutes;
        if (totalAsleep > 0) {
          metrics['SLEEP_ASLEEP'] = {
            'value': totalAsleep.toDouble(), 
            'timestamp': lastSleep.wakeTime
          };
        }
      }

      if (metrics['SLEEP_IN_BED']['value'] == null && lastSleep != null) {
        final totalInBed = lastSleep.inBedMinutes;
        if (totalInBed > 0) {
          metrics['SLEEP_IN_BED'] = {
            'value': totalInBed.toDouble(), 
            'timestamp': lastSleep.wakeTime
          };
        }
      }
      
      print('📊 Total metric types tracked: ${metrics.length}');
      
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
          'Recovery': result.recoveryScore,
          'Fatigue Index': result.fatigueIndex,
          'Endurance': result.enduranceCapacity,
          'Sleep Index': result.sleepIndex,
          'Cardio Fitness': result.cardiovascularFitness,
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
        _confidenceLevels = result.confidenceLevels;
        _componentBreakdowns = result.componentBreakdown;
        _loadingScores = false;
      });
    } catch (e) {
      print('❌ Error calculating scores: $e');
      setState(() => _loadingScores = false);
    }
  }

  bool _isIntervalType(String type) {
    return type.startsWith('SLEEP_') || 
           type == 'MINDFULNESS' || 
           type == 'WORKOUT' || 
           type == 'EXERCISE_TIME' ||
           type == 'ELECTRODERMAL_ACTIVITY' ||
           type == 'BASAL_ENERGY_BURNED' ||
           type == 'ACTIVE_ENERGY_BURNED';
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
                onTap: () {
                  context.push('/score-detail', extra: {
                    'scoreName': entry.key,
                    'scoreValue': score,
                    'components': _componentBreakdowns[entry.key] ?? {},
                    'confidence': _confidenceLevels[entry.key] ?? 'medium',
                  });
                },
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
    if (type.contains('BLOOD_PRESSURE')) return '${value.toStringAsFixed(0)} mmHg';
    if (type.contains('STEPS')) return value.toStringAsFixed(0);
    if (type.contains('FLIGHTS')) return value.toStringAsFixed(0);
    if (type.contains('DISTANCE')) return '${(value / 1000).toStringAsFixed(2)} km';
    if (type.contains('ENERGY')) return '${value.toStringAsFixed(0)} kcal';
    
    // Sleep metrics
    if (type.contains('SLEEP')) {
      // Show total sleep and in-bed in hours for clarity
      if (type == 'SLEEP_ASLEEP' || type == 'SLEEP_IN_BED' || type == 'SLEEP_SESSION') {
        final hours = value / 60.0;
        return '${hours.toStringAsFixed(1)} hrs';
      }
      // Show sleep stages (deep, rem, light, awake) in minutes
      return '${value.toStringAsFixed(0)} min';
    }
    
    // Activity intervals
    if (type.contains('MINDFULNESS') || type.contains('WORKOUT') || type.contains('EXERCISE')) {
      return '${value.toStringAsFixed(0)} min';
    }
    if (type.contains('STAND_TIME') || type.contains('MOVE_TIME')) {
      return '${value.toStringAsFixed(0)} min';
    }
    
    // Body measurements
    if (type == 'WEIGHT' || type.contains('MASS')) return '${value.toStringAsFixed(1)} kg';
    if (type == 'HEIGHT') return '${value.toStringAsFixed(1)} cm';
    if (type == 'BODY_MASS_INDEX') return value.toStringAsFixed(1);
    if (type == 'BODY_FAT_PERCENTAGE') return '${value.toStringAsFixed(1)}%';
    if (type.contains('CIRCUMFERENCE')) return '${value.toStringAsFixed(1)} cm';
    if (type == 'BODY_TEMPERATURE') return '${value.toStringAsFixed(1)}°C';
    
    // Blood glucose
    if (type == 'BLOOD_GLUCOSE') return '${value.toStringAsFixed(0)} mg/dL';
    
    // Menstrual flow (categorical value)
    if (type == 'MENSTRUATION_FLOW') {
      final level = value.toInt();
      if (level == 0) return 'None';
      if (level == 1) return 'Light';
      if (level == 2) return 'Medium';
      if (level == 3) return 'Heavy';
      return 'Level $level';
    }
    
    // Nutrition
    if (type.contains('DIETARY')) {
      if (type.contains('ENERGY')) return '${value.toStringAsFixed(0)} kcal';
      if (type.contains('CAFFEINE') || type.contains('SODIUM')) return '${value.toStringAsFixed(0)} mg';
      return '${value.toStringAsFixed(1)} g';
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
