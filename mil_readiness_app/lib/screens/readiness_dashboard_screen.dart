import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/all_scores_calculator.dart';
import '../models/comprehensive_readiness_result.dart';
import '../models/user_profile.dart';
import '../services/local_secure_store.dart';
import '../services/data_availability_checker.dart';
import '../services/backend_sync_service.dart';
import '../services/insight_generator.dart';
import '../services/anomaly_service.dart';
import '../database/secure_database_manager.dart';
import '../widgets/score_card.dart';
import '../widgets/trend_sparkline.dart';
import '../widgets/manual_logging_fab.dart';
import '../theme/app_theme.dart';
import '../repositories/comprehensive_score_repository.dart';
import '../repositories/day_tag_repository.dart';
import '../services/email_verification_service.dart';
import '../services/readiness_insight_service.dart';
import '../services/data_trust_service.dart';
import '../widgets/email_verification_widgets.dart';
import '../widgets/data_trust_widgets.dart';
import '../widgets/privacy_widgets.dart';
import '../routes.dart';
import '../services/session_controller.dart';
import '../services/live_sync_controller.dart';

/// Elevated Readiness Dashboard with professional insights and micro-interactions
class ReadinessDashboardScreen extends StatefulWidget {
  final SessionController? session;
  const ReadinessDashboardScreen({super.key, this.session});

  @override
  State<ReadinessDashboardScreen> createState() => _ReadinessDashboardScreenState();
}

class _ReadinessDashboardScreenState extends State<ReadinessDashboardScreen> with TickerProviderStateMixin {
  bool _loading = true;
  ComprehensiveReadinessResult? _result;
  List<ComprehensiveReadinessResult> _trendData = [];
  List<String> _currentTags = [];
  String? _email;
  UserProfile? _profile;
  String? _error;
  bool _hasEnoughData = false;
  String _dataStatus = '';
  DateTime _selectedDate = DateTime.now();
  List<AnomalyAlert> _anomalyAlerts = [];
  
  // Backend sync
  BackendSyncService? _backendSync;
  bool _syncInProgress = false;
  bool? _lastSyncSuccess;
  String? _syncError;
  
  // Email verification (non-blocking UI layer)
  bool _emailVerified = true; // Default to true to avoid showing banner unnecessarily
  bool _showVerificationBanner = false;
  
  // Data trust visibility (Phase 4)
  HealthConnectionStatus? _healthConnectionStatus;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initBackendSync();
    _checkDataAndLoadReadiness();
  }
  
  Future<void> _initBackendSync() async {
    try {
      _backendSync = await BackendSyncService.create();
    } catch (e) {
      print('⚠️ Backend sync service initialization failed: $e');
    }
  }

  Future<void> _checkDataAndLoadReadiness() async {
    setState(() => _loading = true);
    try {
      _email = await LocalSecureStore.instance.getActiveSessionEmail();
      if (_email == null) {
        setState(() { _error = 'No active session'; _loading = false; });
        return;
      }
      final db = await SecureDatabaseManager.instance.database;
      final profiles = await db.query('user_profiles', where: 'email = ?', whereArgs: [_email]);
      if (profiles.isNotEmpty) {
        _profile = UserProfile.fromJson(profiles.first);
      } else {
        _profile = UserProfile(email: _email!, fullName: 'User', age: 30, heightCm: 175, weightKg: 75, gender: 'male', targetSleep: 450);
      }
      
      // Check email verification status (non-blocking)
      final verificationService = EmailVerificationService();
      final isVerified = await verificationService.isEmailVerified(_email!);
      setState(() {
        _emailVerified = isVerified;
        _showVerificationBanner = !isVerified; // Show banner if unverified
      });
      
      // Check health connection status and offline mode (Phase 4 - read-only)
      final connectionStatus = await DataTrustService.getHealthConnectionStatus(_email!);
      final offline = await DataTrustService.isOffline();
      setState(() {
        _healthConnectionStatus = connectionStatus;
        _isOffline = offline;
      });
      
      final dataCheck = await DataAvailabilityChecker.check(_email!);
      setState(() { _hasEnoughData = dataCheck.canCalculateReadiness; _dataStatus = dataCheck.statusMessage; });
      if (!dataCheck.canCalculateReadiness) { setState(() => _loading = false); return; }
      await _loadReadiness();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadReadiness() async {
    setState(() => _loading = true);
    try {
      if (_email == null || _profile == null) return;
      
      // TRIGGER HEALTH SYNC FIRST
      final liveSync = widget.session?.liveSync;
      if (liveSync != null) {
        print('🔄 Dashboard: Triggering HealthKit sync before calculation...');
        await liveSync.syncNow();
      }

      final db = await SecureDatabaseManager.instance.database;
      final calculator = AllScoresCalculator(db: SecureDatabaseManager.instance);
      final result = await calculator.calculateAll(userEmail: _email!, date: _selectedDate, profile: _profile!);
      await ComprehensiveScoreRepository.store(userEmail: _email!, date: _selectedDate, result: result);
      final trend = await ComprehensiveScoreRepository.getTrend(userEmail: _email!, days: 7, endDate: _selectedDate);
      final tags = await DayTagRepository.getTagsForDate(userEmail: _email!, date: _selectedDate);

      // Detect anomalies
      final anomalies = AnomalyService.detect(result, trend);

      if (_isToday(_selectedDate) && _profile!.soldierId != null && _backendSync != null) {
        setState(() { _syncInProgress = true; _syncError = null; });
        try {
          final success = await _backendSync!.submitReadinessScores(soldierId: _profile!.soldierId!, date: _selectedDate, result: result);
          setState(() {
            _lastSyncSuccess = success;
            _syncInProgress = false;
            if (success) HapticFeedback.mediumImpact(); // Professional success pulse
            else _syncError = 'Failed to sync with backend';
          });
        } catch (e) {
          setState(() { _lastSyncSuccess = false; _syncInProgress = false; _syncError = 'Sync error: $e'; });
        }
      }

      setState(() { 
        _result = result; 
        _trendData = trend; 
        _currentTags = tags; 
        _anomalyAlerts = anomalies;
        _loading = false; 
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 MILITARY READINESS'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Scores',
            onPressed: () { HapticFeedback.lightImpact(); _loadReadiness(); },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date',
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: AppTheme.accentRed)))
              : !_hasEnoughData
                  ? _buildDataCollectionScreen()
                  : _result == null
                      ? const Center(child: Text('No readiness data available.'))
                      : Scaffold(
                          backgroundColor: Colors.transparent,
                          floatingActionButton: ManualLoggingFAB(userEmail: _email!),
                          body: RefreshIndicator(
                            onRefresh: _loadReadiness,
                            color: AppTheme.primaryCyan,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  if (_anomalyAlerts.isNotEmpty) ...[
                                    ..._anomalyAlerts.map((a) => _buildAnomalyBanner(a)).toList(),
                                    const SizedBox(height: 12),
                                  ],
                                  if (_showVerificationBanner) ...[
                                    EmailVerificationBanner(
                                      onResendVerification: _handleResendVerification,
                                      onDismiss: _dismissVerificationBanner,
                                    ),
                                  ],
                                  if (_syncError != null) _buildAlertCard(_syncError!),
                                  if (_syncError != null) const SizedBox(height: 12),
                                  if (_isOffline) ...[
                                    const OfflineModeIndicator(),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildPurposeBanner(),
                                  const SizedBox(height: 8),
                                  if (_result != null) ...[
                                    SyncFreshnessIndicator(lastSyncTime: _result!.calculatedAt),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildSystemStatusBadge(),
                                  const SizedBox(height: 12),
                                  _buildOverallReadinessCard(),
                                  const SizedBox(height: 24),
                                  _buildDailyInsightBlock(),
                                  const SizedBox(height: 24),
                                  _buildWhyTodaysScoreBlock(),
                                  const SizedBox(height: 24),
                                  if (_healthConnectionStatus != null) ...[
                                    ConnectedSourcesCard(
                                      connectionStatus: _healthConnectionStatus!,
                                      onManageConnection: () => _showConnectionManagementInfo(context),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildCalmSyncMessage(),
                                  if (_healthConnectionStatus != null && _healthConnectionStatus!.hasLimitedAccess) ...[
                                    PermissionAwarenessBanner(
                                      onTap: () => _showConnectionManagementInfo(context),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildTagSection(),
                                  const SizedBox(height: 24),
                                  _buildScoreSection(title: 'CORE READINESS', icon: Icons.battery_charging_full_outlined, scores: _result!.getScoresByCategory()['Core']!),
                                  const SizedBox(height: 24),
                                  _buildScoreSection(title: 'SAFETY & MONITORING', icon: Icons.shield_outlined, scores: _result!.getScoresByCategory()['Safety']!),
                                  const SizedBox(height: 24),
                                  _buildScoreSection(title: 'OPERATIONAL SPECIALTY', icon: Icons.star_border_outlined, scores: _result!.getScoresByCategory()['Specialty']!),
                                  const SizedBox(height: 32),
                                  PrivacySummaryCard(
                                    onTap: () => context.push('/privacy-info'),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildMetadataCard(),
                                ],
                              ),
                            ),
                          ),
                        ),
    );
  }

  /// System Status with Pulse and Sync
  Widget _buildSystemStatusBadge() {
    final hasEnoughHistory = _trendData.length >= 3;
    final color = hasEnoughHistory ? AppTheme.accentGreen : AppTheme.primaryCyan;
    final label = hasEnoughHistory ? 'SYSTEM OPERATIONAL' : 'LEARNING MODE (BASELINE)';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          _PulseIndicator(color: color),
          const SizedBox(width: 8),
          Text(label, style: AppTheme.captionStyle.copyWith(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ]),
        _buildSmallSyncStatus(),
      ],
    );
  }

  Widget _buildSmallSyncStatus() {
    final now = DateTime.now();
    final lastSync = _result?.calculatedAt ?? now;
    final diff = now.difference(lastSync);
    final isStale = diff.inHours >= 4;
    final color = isStale ? AppTheme.accentOrange : AppTheme.accentGreen;
    final timeStr = diff.inMinutes < 1 ? 'JUST NOW' : '${diff.inMinutes}M AGO';
    return Text(isStale ? 'STALE' : 'LAST SYNCED: $timeStr', style: AppTheme.captionStyle.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.bold));
  }

  /// Hero Card with animated score and interpretation
  Widget _buildOverallReadinessCard() {
    final score = _result!.overallReadiness;
    final tacticalStatus = InsightGenerator.getStatusLabel(score);
    final color = _getCategoryColor(score);
    final trendLabel = InsightGenerator.getTrendLabel(_trendData);
    final interpretation = InsightGenerator.getSummaryInterpretation(_result!, _trendData);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(),
      child: Column(
        children: [
          const Text('OVERALL READINESS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: AppTheme.textWhite)),
          const SizedBox(height: 24),
          
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: score),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(width: 170, height: 170, child: CircularProgressIndicator(value: value / 100, strokeWidth: 10, backgroundColor: AppTheme.glassBorder, color: color)),
                  Column(children: [
                    Text(value.toStringAsFixed(0), style: TextStyle(fontSize: 58, fontWeight: FontWeight.bold, color: color)),
                    Text(tacticalStatus, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold, letterSpacing: 3)),
                  ]),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          Text(interpretation, textAlign: TextAlign.center, style: AppTheme.bodyStyle.copyWith(color: AppTheme.textLight, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          _buildDataConfidenceBadge(),
          const SizedBox(height: 24),

          if (_trendData.length > 1) ...[
            Row(children: [
              const Text('7-DAY TREND', style: TextStyle(color: AppTheme.textGray, fontSize: 10, letterSpacing: 1)),
              const Spacer(),
              Text(trendLabel, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            TrendSparkline(data: _trendData.map((e) => e.overallReadiness).toList(), color: color, height: 40, showPoints: true),
          ],
        ],
      ),
    );
  }

  /// Daily Insight Sentence Block
  Widget _buildDailyInsightBlock() {
    final insight = InsightGenerator.getDailyInsight(_trendData);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(color: AppTheme.primaryBlue.withOpacity(0.05)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.psychology_outlined, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text('DAILY SYSTEM INSIGHT', style: AppTheme.titleStyle.copyWith(color: AppTheme.primaryBlue)),
          ]),
          const SizedBox(height: 12),
          Text(insight, style: AppTheme.bodyStyle.copyWith(color: AppTheme.textWhite, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildTagSection() {
    final availableTags = [
      {'label': 'Travel', 'icon': Icons.flight_takeoff},
      {'label': 'Night Duty', 'icon': Icons.nightlight_round},
      {'label': 'Heavy Load', 'icon': Icons.fitness_center},
      {'label': 'Illness', 'icon': Icons.medical_services},
      {'label': 'High Stress', 'icon': Icons.warning_amber_rounded},
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.tag, color: AppTheme.primaryCyan, size: 20), const SizedBox(width: 8), Text('CONTEXT JOURNAL', style: AppTheme.titleStyle)]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: availableTags.map((tagData) {
          final label = tagData['label'] as String;
          final isSelected = _currentTags.contains(label);
          return FilterChip(
            label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? AppTheme.textWhite : AppTheme.textGray)),
            avatar: Icon(tagData['icon'] as IconData, size: 14, color: isSelected ? AppTheme.textWhite : AppTheme.textGray),
            selected: isSelected,
            onSelected: (_) => _toggleTag(label),
            selectedColor: AppTheme.primaryCyan.withOpacity(0.5),
            backgroundColor: AppTheme.glassBorder.withOpacity(0.1),
            checkmarkColor: AppTheme.textWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: isSelected ? AppTheme.primaryCyan : AppTheme.glassBorder),
          );
        }).toList()),
      ]),
    );
  }

  Future<void> _toggleTag(String tag) async {
    if (_email == null) return;
    HapticFeedback.lightImpact();
    if (_currentTags.contains(tag)) {
      await DayTagRepository.removeTag(userEmail: _email!, date: _selectedDate, tag: tag);
      setState(() => _currentTags.remove(tag));
    } else {
      await DayTagRepository.addTag(userEmail: _email!, date: _selectedDate, tag: tag);
      setState(() => _currentTags.add(tag));
    }
  }

  Widget _buildScoreSection({required String title, required IconData icon, required Map<String, double> scores}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 16), child: Row(children: [Icon(icon, size: 20, color: AppTheme.primaryCyan), const SizedBox(width: 10), Text(title, style: AppTheme.titleStyle.copyWith(letterSpacing: 2))])),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: scores.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = scores.entries.toList()[index];
          final confidence = _result!.confidenceLevels[entry.key] ?? 'medium';
          final miniTrend = _trendData.map((res) => res.getAllScores()[entry.key] ?? 0.0).toList();
          return _buildDetailedScoreTile(name: entry.key, value: entry.value, confidence: confidence, trend: miniTrend, icon: _getIconForScore(entry.key), onTap: () {
            context.push('/score-detail', extra: {'scoreName': entry.key, 'scoreValue': entry.value, 'components': _result!.componentBreakdown[entry.key] ?? {}, 'confidence': confidence});
          });
        },
      ),
    ]);
  }

  Widget _buildDetailedScoreTile({required String name, required double value, required String confidence, required List<double> trend, required IconData icon, required VoidCallback onTap}) {
    final color = _getCategoryColor(value);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassCard(),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              Text(confidence.toUpperCase(), style: TextStyle(fontSize: 10, color: confidence == 'high' ? AppTheme.accentGreen : (confidence == 'low' ? AppTheme.accentOrange : AppTheme.primaryBlue), fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (trend.length > 1) SizedBox(width: 60, height: 12, child: TrendSparkline(data: trend, color: color.withOpacity(0.5), height: 12, useGradient: false)),
            ]),
          ])),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value.toStringAsFixed(0), style: AppTheme.titleStyle.copyWith(fontSize: 24, color: color)),
            Text('/100', style: AppTheme.captionStyle.copyWith(fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAnomalyBanner(AnomalyAlert alert) {
    final color = alert.isCritical ? AppTheme.accentRed : AppTheme.accentOrange;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alert.isCritical ? Icons.report_problem : Icons.warning_amber_rounded, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'TACTICAL ALERT: ${alert.metric.toUpperCase()}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
                ),
              ),
              if (alert.isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  child: const Text('CRITICAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(alert.message, style: AppTheme.bodyStyle.copyWith(color: AppTheme.textWhite, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.textGray, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(alert.tacticalRecommendation, style: AppTheme.captionStyle.copyWith(color: AppTheme.textLight, height: 1.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.accentOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.accentOrange.withOpacity(0.5))),
      child: Row(children: [const Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 20), const SizedBox(width: 12), Expanded(child: Text(message, style: AppTheme.bodyStyle.copyWith(color: AppTheme.accentOrange, fontSize: 13, fontWeight: FontWeight.bold)))]),
    );
  }

  Widget _buildPrivacySecurityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.lock_outline, color: AppTheme.primaryCyan, size: 20),
          const SizedBox(width: 12),
          Text('SECURITY STATUS', style: AppTheme.titleStyle),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppTheme.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Text('ENCRYPTED', style: TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        Text('Operational data is stored using AES-256 encryption. Raw health data remains on-device.', style: AppTheme.captionStyle),
      ]),
    );
  }

  Widget _buildMetadataCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.info_outline, color: AppTheme.primaryCyan, size: 20), const SizedBox(width: 12), Text('CALCULATION ENGINE', style: AppTheme.titleStyle)]),
        const Divider(height: 24, color: AppTheme.glassBorder),
        _infoRow('Calculated', DateFormat('HH:mm').format(_result!.calculatedAt)),
        _infoRow('Effective Date', _formatDate(_selectedDate)),
        _infoRow('Algorithm Version', '2.4.0 (AUIX-MIL)'),
        if (_profile?.soldierId != null) ...[
          const Divider(height: 24, color: AppTheme.glassBorder),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Operational Sync', style: AppTheme.captionStyle),
            if (_syncInProgress) Row(children: const [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan)), SizedBox(width: 8), Text('UPLOADING...', style: TextStyle(color: AppTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold))])
            else if (_lastSyncSuccess == true) Row(children: const [Icon(Icons.cloud_done, color: AppTheme.accentGreen, size: 16), SizedBox(width: 4), Text('VERIFIED', style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold))])
            else const Text('OFFLINE CACHE', style: TextStyle(color: AppTheme.textGray, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ],
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: AppTheme.captionStyle), Text(value, style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold))]));
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 90)), lastDate: DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(primary: AppTheme.primaryCyan, surface: AppTheme.bgDark)), child: child!));
    if (picked != null && picked != _selectedDate) { HapticFeedback.lightImpact(); setState(() => _selectedDate = picked); _loadReadiness(); }
  }

  Color _getCategoryColor(double score) => score >= 80 ? AppTheme.accentGreen : (score >= 60 ? AppTheme.accentOrange : AppTheme.accentRed);
  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  IconData _getIconForScore(String scoreName) {
    final iconMap = {
      'Recovery': Icons.monitor_heart_outlined,
      'Sleep Index': Icons.bedtime_outlined,
      'Fatigue Index': Icons.battery_alert_outlined,
      'Endurance': Icons.directions_run_outlined,
      'Cardio Fitness': Icons.favorite_border_outlined,
      'Work Capacity': Icons.fitness_center_outlined,
      'Stress Load': Icons.psychology_outlined,
      'Injury Risk': Icons.healing_outlined,
      'Cardio-Resp Stability': Icons.speed_outlined,
      'Illness Risk': Icons.medical_services_outlined,
      'Daily Activity': Icons.directions_walk_outlined,
      'Cardiac Safety': Icons.heart_broken_outlined,
      'Altitude': Icons.terrain_outlined,
      'Sleep Debt': Icons.nights_stay_outlined,
      'Training Readiness': Icons.sports_score_outlined,
      'Cognitive Alertness': Icons.lightbulb_outline,
      'Thermoregulatory': Icons.thermostat_outlined,
    };
    return iconMap[scoreName] ?? Icons.analytics_outlined;
  }
  
  /// Data confidence indicator badge
  Widget _buildDataConfidenceBadge() {
    final confidence = ReadinessInsightService.calculateDataConfidence(_result!, _trendData);
    final explanation = ReadinessInsightService.getConfidenceExplanation(confidence);
    
    Color badgeColor;
    if (confidence == 'High') {
      badgeColor = AppTheme.accentGreen;
    } else if (confidence == 'Medium') {
      badgeColor = AppTheme.accentOrange;
    } else {
      badgeColor = AppTheme.textGray;
    }
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_outlined, size: 14, color: badgeColor),
              const SizedBox(width: 6),
              Text(
                'Data Confidence: $confidence',
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          explanation,
          style: AppTheme.captionStyle.copyWith(
            color: AppTheme.textGray,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  /// "Why today's score" block - top 3 factors (max 3 items, no equations)
  Widget _buildWhyTodaysScoreBlock() {
    final topFactors = ReadinessInsightService.generateTopFactors(_result!, _trendData);
    
    if (topFactors.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: AppTheme.primaryCyan, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Why Today\'s Score',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppTheme.textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topFactors.asMap().entries.map((entry) {
            final index = entry.key;
            final factor = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < topFactors.length - 1 ? 12 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      factor,
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.textLight,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  /// Purpose banner - clear one-line app explanation
  Widget _buildPurposeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: AppTheme.primaryCyan.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your daily readiness, calculated securely from your health data.',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.textLight,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCollectionScreen() {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.hourglass_empty, size: 64, color: AppTheme.accentOrange),
        const SizedBox(height: 16),
        const Text('COLLECTING BASELINE...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        Text(_dataStatus, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 32),
        Text('Establishing your operational baseline. Initial scores will be available once sufficient data coverage is achieved.', textAlign: TextAlign.center, style: AppTheme.captionStyle),
    ])));
  }
  
  /// Email verification handlers (non-blocking UI layer)
  Future<void> _handleResendVerification() async {
    if (_email == null) return;
    
    final service = EmailVerificationService();
    
    // Check rate limit
    if (!service.canResendVerification(_email!)) {
      final remaining = service.getRemainingCooldown(_email!);
      service.showRateLimitSnackBar(context, remaining);
      return;
    }
    
    // Attempt to send verification email
    final success = await service.resendVerificationEmail(_email!);
    
    if (success && mounted) {
      service.showVerificationSentSnackBar(context, _email!);
      service.showBackendPendingNotice(context); // Dev notice
    }
  }
  
  void _dismissVerificationBanner() {
    setState(() {
      _showVerificationBanner = false;
    });
  }
  
  /// Calm sync messaging (Phase 4 - non-scary)
  Widget _buildCalmSyncMessage() {
    if (_result == null || _healthConnectionStatus == null) {
      return const SizedBox.shrink();
    }
    
    final freshness = DataTrustService.calculateSyncFreshness(_result!.calculatedAt);
    final message = DataTrustService.getCalmDelayedMessage(
      freshness,
      _healthConnectionStatus!.isConnected,
    );
    
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        CalmSyncMessageBanner(
          message: message,
          isWarning: !_healthConnectionStatus!.isConnected,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
  
  /// Show connection management info dialog (Phase 4 - simple explanation)
  void _showConnectionManagementInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgDark,
        title: const Text(
          'Health Data Connection',
          style: TextStyle(color: AppTheme.textWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your health data source is managed through device settings.',
              style: TextStyle(color: AppTheme.textLight),
            ),
            const SizedBox(height: 16),
            if (Platform.isIOS) ...[
              Text(
                'To modify Apple Health permissions:\n\n'
                '1. Open Settings app\n'
                '2. Go to Health → Data Access & Devices\n'
                '3. Select Military Readiness\n'
                '4. Update permissions',
                style: TextStyle(color: AppTheme.textLight, fontSize: 13),
              ),
            ] else ...[
              Text(
                'To modify Health Connect permissions:\n\n'
                '1. Open Settings app\n'
                '2. Go to Health Connect\n'
                '3. Select Military Readiness\n'
                '4. Update permissions',
                style: TextStyle(color: AppTheme.textLight, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it', style: TextStyle(color: AppTheme.primaryCyan)),
          ),
        ],
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  final Color color;
  const _PulseIndicator({required this.color});
  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (context, child) => Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.5 + (_controller.value * 0.5)), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5 * _controller.value), blurRadius: 10 * _controller.value, spreadRadius: 2 * _controller.value)])));
  }
}
