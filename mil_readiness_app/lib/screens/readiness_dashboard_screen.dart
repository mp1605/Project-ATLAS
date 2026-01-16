import 'package:flutter/material.dart';
import '../services/all_scores_calculator.dart';
import '../models/comprehensive_readiness_result.dart';
import '../models/user_profile.dart';
import '../services/local_secure_store.dart';
import '../services/data_availability_checker.dart';
import '../services/backend_sync_service.dart';
import '../database/secure_database_manager.dart';
import '../widgets/score_card.dart';


/// Main readiness dashboard showing all 18 military readiness scores
class ReadinessDashboardScreen extends StatefulWidget {
  const ReadinessDashboardScreen({super.key});

  @override
  State<ReadinessDashboardScreen> createState() => _ReadinessDashboardScreenState();
}

class _ReadinessDashboardScreenState extends State<ReadinessDashboardScreen> {
  bool _loading = true;
  ComprehensiveReadinessResult? _result;
  String? _email;
  UserProfile? _profile;
  String? _error;
  bool _hasEnoughData = false;
  String _dataStatus = '';
  DateTime _selectedDate = DateTime.now();
  
  // Backend sync
  BackendSyncService? _backendSync;
  bool _syncInProgress = false;
  bool? _lastSyncSuccess;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _initBackendSync();
    _checkDataAndLoadReadiness();
  }
  
  Future<void> _initBackendSync() async {
    try {
      _backendSync = await BackendSyncService.create();
      print('📡 Backend sync service initialized');
    } catch (e) {
      print('⚠️ Backend sync service initialization failed: $e');
    }
  }

  Future<void> _checkDataAndLoadReadiness() async {
    setState(() => _loading = true);
    
    try {
      _email = await LocalSecureStore.instance.getActiveSessionEmail();
      
      if (_email == null) {
        setState(() {
          _error = 'No active session';
          _loading = false;
        });
        return;
      }

      // Load user profile
      final db = await SecureDatabaseManager.instance.database;
      final profiles = await db.query(
        'user_profiles',
        where: 'email = ?',
        whereArgs: [_email],
      );
      
      if (profiles.isNotEmpty) {
        _profile = UserProfile.fromJson(profiles.first);
      } else {
        // Create default profile
        _profile = UserProfile(
          email: _email!,
          fullName: 'User',
          age: 30,
          heightCm: 175,
          weightKg: 75,
          gender: 'male',
          targetSleep: 450,
        );
      }

      // Check data availability first
      final dataCheck = await DataAvailabilityChecker.check(_email!);
      setState(() {
        _hasEnoughData = dataCheck.canCalculateReadiness;
        _dataStatus = dataCheck.statusMessage;
      });

      if (!dataCheck.canCalculateReadiness) {
        setState(() => _loading = false);
        return;
      }

      await _loadReadiness();
    } catch (e, stackTrace) {
      print('Error checking data: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadReadiness() async {
    setState(() => _loading = true);
    
    try {
      if (_email == null || _profile == null) return;

      final db = await SecureDatabaseManager.instance.database;
      final calculator = AllScoresCalculator(db: SecureDatabaseManager.instance);

      final result = await calculator.calculateAll(
        userEmail: _email!,
        date: _selectedDate,
        profile: _profile!,
      );

      // NEW: Submit to backend if today's scores AND soldier_id is set
      if (_isToday(_selectedDate) && _profile!.soldierId != null && _backendSync != null) {
        setState(() {
          _syncInProgress = true;
          _syncError = null;
        });
        
        try {
          final success = await _backendSync!.submitReadinessScores(
            soldierId: _profile!.soldierId!,
            date: _selectedDate,
            result: result,
          );
          
          setState(() {
            _lastSyncSuccess = success;
            _syncInProgress = false;
            if (!success) {
              _syncError = 'Failed to sync with backend';
            }
          });
        } catch (e) {
          setState(() {
            _lastSyncSuccess = false;
            _syncInProgress = false;
            _syncError = 'Sync error: ${e.toString()}';
          });
        }
      }

      setState(() {
        _result = result;
        _loading = false;
      });

    } catch (e, stackTrace) {
      print('Error loading readiness: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Military Readiness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Scores',
            onPressed: _loadReadiness,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date',
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: Colors.red)))
              : !_hasEnoughData
                  ? _buildDataCollectionScreen()
                  : _result == null
                      ? const Center(child: Text('No readiness data available.'))
                      : RefreshIndicator(
                          onRefresh: _loadReadiness,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Hero Card: Overall Readiness
                                _buildOverallReadinessCard(),
                                const SizedBox(height: 20),
                                
                                // Core Scores Section
                                _buildScoreSection(
                                  title: 'CORE SCORES',
                                  icon: Icons.favorite,
                                  scores: _result!.getScoresByCategory()['Core']!,
                                ),
                                const SizedBox(height: 20),
                                
                                // Safety Scores Section
                                _buildScoreSection(
                                  title: 'SAFETY & MONITORING',
                                  icon: Icons.shield,
                                  scores: _result!.getScoresByCategory()['Safety']!,
                                ),
                                const SizedBox(height: 20),
                                
                                // Specialty Scores Section
                                _buildScoreSection(
                                  title: 'SPECIALTY SCORES',
                                  icon: Icons.star,
                                  scores: _result!.getScoresByCategory()['Specialty']!,
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Metadata
                                _buildMetadataCard(),
                              ],
                            ),
                          ),
                        ),
    );
  }

  /// Build hero card for overall readiness
  Widget _buildOverallReadinessCard() {
    final score = _result!.overallReadiness;
    final category = _result!.category;
    final color = _getCategoryColor(score);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'OVERALL READINESS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            
            // Circular progress indicator
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 14,
                    backgroundColor: Colors.grey[300],
                    color: color,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getCategoryIcon(category), color: color, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Confidence badge
            _buildConfidenceBadge(_result!.overallConfidence),
          ],
        ),
      ),
    );
  }

  /// Build a section of score cards
  Widget _buildScoreSection({
    required String title,
    required IconData icon,
    required Map<String, double> scores,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        
        // Score cards in 2x3 grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: scores.length,
          itemBuilder: (context, index) {
            final entry = scores.entries.toList()[index];
            final scoreName = entry.key;
            final scoreValue = entry.value;
            final category = getCategoryFromScore(scoreValue);
            final confidence = _result!.confidenceLevels[scoreName] ?? 'medium';
            
            return ScoreCard(
              scoreName: scoreName,
              scoreValue: scoreValue,
              category: category,
              confidence: confidence,
              icon: _getIconForScore(scoreName),
              onTap: () {
                // TODO: Navigate to score detail screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$scoreName: ${scoreValue.toStringAsFixed(0)}')),
                );
              },
              compact: true,
            );
          },
        ),
      ],
    );
  }

  /// Build metadata card showing calculation time and confidence
  Widget _buildMetadataCard() {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Score Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const Divider(),
            _infoRow('Calculated', _formatDateTime(_result!.calculatedAt)),
            _infoRow('Date', _formatDate(_selectedDate)),
            _infoRow('Overall Confidence', _result!.overallConfidence.toUpperCase()),
            
            // Backend sync status
            if (_profile?.soldierId != null) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Backend Sync', style: TextStyle(color: Colors.grey[600])),
                  if (_syncInProgress)
                    Row(
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Syncing...',style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    )
                  else if (_lastSyncSuccess == true)
                    Row(
                      children: const [
                        Icon(Icons.cloud_done, color: Colors.green, size: 18),
                        SizedBox(width: 4),
                        Text('Synced', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    )
                  else if (_lastSyncSuccess == false)
                    Row(
                      children: const [
                        Icon(Icons.cloud_off, color: Colors.orange, size: 18),
                        SizedBox(width: 4),
                        Text('Offline', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                      ],
                    )
                  else
                    const Text('Not synced', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (_syncError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _syncError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Build data collection screen when insufficient data
  Widget _buildDataCollectionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Collecting Data...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              _dataStatus,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            Text(
              'Keep wearing your Apple Watch and the app will calculate your readiness scores once enough data is collected.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build confidence badge
  Widget _buildConfidenceBadge(String confidence) {
    Color badgeColor;
    IconData badgeIcon;
    
    switch (confidence.toLowerCase()) {
      case 'high':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        break;
      case 'low':
        badgeColor = Colors.orange;
        badgeIcon = Icons.warning;
        break;
      default:
        badgeColor = Colors.blue;
        badgeIcon = Icons.info;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: badgeColor, size: 18),
          const SizedBox(width: 8),
          Text(
            '${confidence.toUpperCase()} CONFIDENCE',
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReadiness();
    }
  }

  /// Get color based on score
  Color _getCategoryColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.yellow[700]!;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  /// Get icon for category
  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'GO':
        return Icons.check_circle;
      case 'CAUTION':
        return Icons.warning;
      case 'LIMITED':
        return Icons.error;
      case 'STOP':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  /// Get icon for specific score
  IconData _getIconForScore(String scoreName) {
    final iconMap = {
      'Recovery': Icons.favorite,
      'Sleep Index': Icons.bedtime,
      'Fatigue Index': Icons.battery_alert,
      'Endurance': Icons.directions_run,
      'Cardio Fitness': Icons.favorite_border,
      'Work Capacity': Icons.fitness_center,
      'Stress Load': Icons.psychology,
      'Injury Risk': Icons.healing,
      'Cardio-Resp Stability': Icons.monitor_heart,
      'Illness Risk': Icons.health_and_safety,
      'Daily Activity': Icons.directions_walk,
      'Cardiac Safety': Icons.monitor_heart,
      'Altitude': Icons.terrain,
      'Sleep Debt': Icons.nightlight,
      'Training Readiness': Icons.sports_score,
      'Cognitive Alertness': Icons.lightbulb,
      'Thermoregulation': Icons.thermostat,
    };
    return iconMap[scoreName] ?? Icons.analytics;
  }

  /// Format date time
  String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Format date
  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
