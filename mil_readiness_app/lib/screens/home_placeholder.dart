import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../routes.dart';
import '../database/secure_database_manager.dart';
import '../services/local_secure_store.dart';
import '../services/live_sync_controller.dart';
import '../services/last_sleep_service.dart';
import '../services/sleep_source_resolver.dart';
import '../adapters/health_adapter_factory.dart';
import '../models/wearable_type.dart';
import '../repositories/manual_activity_repository.dart';

/// Clean, professional home screen for soldiers with real data
class HomePlaceholder extends StatefulWidget {
  final SessionController session;
  const HomePlaceholder({super.key, required this.session});

  @override
  State<HomePlaceholder> createState() => _HomePlaceholderState();
}

class _HomePlaceholderState extends State<HomePlaceholder> {
  // Real-time stats
  String _heartRate = '--';
  String _hrv = '--';
  String _sleep = '--';
  String _manualLoad = '0';
  DateTime? _lastUpdated;
  
  Timer? _refreshTimer;
  LiveSyncController? _liveSync;

  @override
  void initState() {
    super.initState();
    
    // PATCH 3: Auto-request Health permissions on first load
    _requestHealthPermissionsIfNeeded();
    
    // Start real-time stats refresh
    _loadRealTimeStats();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadRealTimeStats(),
    );
    
    // Initialize LiveSync for this user
    _initializeLiveSync();
  }
  
  
  /// Request Health permissions automatically if not already granted
  Future<void> _requestHealthPermissionsIfNeeded() async {
    final email = widget.session.email;
    if (email == null) {
      print('❌ No email found, skipping permission request');
      return;
    }

    print('🔍 Checking Health permissions for $email...');

    try {
      final adapter = HealthAdapterFactory.createAdapter(WearableType.appleWatch);
      
      // iOS doesn't reliably tell us permission status via hasPermissions()
      // Instead, try to actually READ data - if we get data, permissions are granted
      print('  → Testing if we can read Health data...');
      
      final testMetrics = await adapter.getMetrics(window: const Duration(hours: 24));
      
      if (testMetrics.isNotEmpty) {
        // We successfully read data - permissions are working!
        print('✅ Health permissions verified - got ${testMetrics.length} data points');
        await LocalSecureStore.instance.setHealthAuthorizedFor(email, true);
        return; // No need to prompt
      }
      
      // No data returned - could be:
      // 1. Permissions not granted
      // 2. No data in HealthKit yet (new watch, no workouts)
      // 
      // Check if we've already prompted this user before
      final alreadyAsked = await LocalSecureStore.instance.getHealthAuthorizedFor(email);
      if (alreadyAsked) {
        // User was already prompted - don't spam them
        print('ℹ️ Already prompted for permissions before - not showing dialog again');
        return;
      }
      
      // First time - show permission dialog
      print('🔐 First time user - showing Health permission dialog...');
      
      // Show explanation dialog with solid, readable styling
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white, // Solid white background
            elevation: 24, // Strong shadow for visibility
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Health Data Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            content: const Text(
              'This app needs access to your Health data to calculate readiness scores.\n\n'
              'You\'ll be asked to grant READ permissions for:\n'
              '• Heart Rate, HRV & Blood Oxygen\n'
              '• Sleep Stages & Duration\n'
              '• Activity (Steps, Exercise, Distance)\n'
              '• Body Metrics (Weight, Body Fat)\n'
              '• Stress Indicators (EDA, Mindfulness)\n\n'
              'Total: 35 core readiness metrics\n\n'
              'Your data stays encrypted on your device.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  
                  // Mark as asked BEFORE the request to ensure we don't spam
                  await LocalSecureStore.instance.setHealthAuthorizedFor(email, true);
                  
                  // Request permissions
                  final granted = await adapter.requestPermissions();
                  
                  if (!granted && mounted) {
                    // Show settings instruction
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Text(
                          'Permissions Required',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'Please grant Health permissions in:\n\n'
                          'Settings → Privacy & Security → Health → {App Name}\n\n'
                          'Then restart the app.',
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text('Grant Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('⚠️ Error checking Health permissions: $e');
    }
  }

  Future<void> _initializeLiveSync() async {
    final email = widget.session.email ?? '';
    if (email.isEmpty) return;

    final selectedWearableName = await LocalSecureStore.instance.getSelectedWearableFor(email);
    final wearableType = selectedWearableName != null
        ? WearableType.values.byName(selectedWearableName)
        : WearableType.appleWatch;

    final adapter = HealthAdapterFactory.createAdapter(wearableType);

    _liveSync = LiveSyncController(
      healthAdapter: adapter,
      store: LocalSecureStore.instance,
      email: email,
      interval: const Duration(seconds: 60),
      window: const Duration(minutes: 10),
    );

    // Listen to sync completion to update stats immediately
    _liveSync!.lastSyncAt.addListener(() {
      if (mounted) {
        // Refresh stats whenever LiveSync completes a collection
        _loadRealTimeStats();
      }
    });

    _liveSync!.start();
    print('✅ LiveSync started - home screen stats update automatically when new data arrives');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _liveSync?.lastSyncAt.dispose();
    // Don't stop LiveSync - let it continue running
    super.dispose();
  }

  Future<void> _loadRealTimeStats() async {
    try {
      print('🏠 Home screen: Loading real-time stats...');
      final db = await SecureDatabaseManager.instance.database;
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      // Get latest heart rate (Try continuous first, then resting)
      final hrResults = await db.rawQuery('''
        SELECT value, timestamp, metric_type FROM health_metrics 
        WHERE (metric_type = 'HEART_RATE' OR metric_type = 'RESTING_HEART_RATE')
        AND timestamp >= ?
        ORDER BY (CASE WHEN metric_type = 'HEART_RATE' THEN 1 ELSE 2 END), timestamp DESC 
        LIMIT 1
      ''', [yesterday.millisecondsSinceEpoch]);

      print('  💓 Heart Rate query: ${hrResults.length} results');
      if (hrResults.isNotEmpty) {
        print('    Value: ${hrResults.first['value']}, Time: ${DateTime.fromMillisecondsSinceEpoch(hrResults.first['timestamp'] as int)}');
      }

      // Get latest HRV - try multiple metric types
      final hrvResults = await db.rawQuery('''
        SELECT value, timestamp, metric_type FROM health_metrics 
        WHERE (metric_type LIKE '%VARIABILITY%' OR metric_type LIKE '%HRV%')
        AND timestamp >= ?
        ORDER BY timestamp DESC 
        LIMIT 1
      ''', [yesterday.millisecondsSinceEpoch]);

      print('  📊 HRV query: ${hrvResults.length} results');
      if (hrvResults.isNotEmpty) {
        print('    Type: ${hrvResults.first['metric_type']}, Value: ${hrvResults.first['value']}');
      }

      // Get LATEST SLEEP - uses SleepSourceResolver to pick best source (auto or manual)
      final todayDate = SleepSourceResolver.getTodayWakeDate();
      final resolvedSleep = await SleepSourceResolver.getSleepForDate(widget.session.email!, todayDate);

      if (mounted) {
        setState(() {
          if (hrResults.isNotEmpty && hrResults.first['value'] != null) {
            _heartRate = hrResults.first['value'].toString().split('.')[0];
            _lastUpdated = DateTime.fromMillisecondsSinceEpoch(hrResults.first['timestamp'] as int);
          }
          if (hrvResults.isNotEmpty && hrvResults.first['value'] != null) {
            _hrv = hrvResults.first['value'].toString().split('.')[0];
          }
          if (!resolvedSleep.isMissing) {
            final hours = resolvedSleep.minutes / 60.0;
            _sleep = hours.toStringAsFixed(1);
          }
        });
        print('  ✅ Stats updated: HR=$_heartRate, HRV=$_hrv, Sleep=$_sleep');
        
        // Load manual activity load for today
        _loadManualLoad();
        
        if (_lastUpdated != null) {
          print('  ⏰ Last heart rate measurement: ${_lastUpdated!.toLocal()}');
        }
      }
    } catch (e) {
      print('❌ Error loading stats: $e');
    }
  }

  Future<void> _loadManualLoad() async {
    final email = widget.session.email;
    if (email == null) return;

    try {
      final repo = ManualActivityRepository();
      final entries = await repo.listForDay(userEmail: email, dayLocal: DateTime.now());
      
      int totalLoad = 0;
      for (final entry in entries) {
        double multiplier = 1.0;
        final loadVal = entry.loadValue;
        if (loadVal != null) {
          if (loadVal > 45) {
            multiplier = 1.30;
          } else if (loadVal >= 26) {
            multiplier = 1.20;
          } else if (loadVal >= 11) {
            multiplier = 1.10;
          } else if (loadVal > 0) {
            multiplier = 1.05;
          }
        }
        totalLoad += (entry.durationMinutes * entry.rpe * multiplier).toInt();
      }

      if (mounted) {
        setState(() {
          _manualLoad = totalLoad.toString();
        });
      }
    } catch (e) {
      print('⚠️ Error loading manual load: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.session.email ?? '';
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header with AUIX logo and settings
              _buildHeader(context),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // Welcome message
                      Text(
                        'SOLDIER READINESS',
                        style: AppTheme.headingStyle.copyWith(fontSize: 28),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email.toUpperCase(),
                        style: AppTheme.captionStyle.copyWith(
                          color: AppTheme.primaryCyan,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Quick stats cards with real data
                      _buildQuickStatsRow(),
                      
                      // Last updated indicator
                      if (_lastUpdated != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Last updated: ${_formatTimeSince(_lastUpdated!)}',
                          style: AppTheme.captionStyle.copyWith(fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      
                      const SizedBox(height: 30),
                      
                      // Main action buttons
                      _buildActionButton(
                        context,
                        icon: Icons.monitor_heart,
                        label: 'DATA MONITOR',
                        subtitle: 'Real-time health metrics',
                        color: AppTheme.primaryCyan,
                        onTap: () => context.push('/data-monitor'),
                      ),
                      
                      const SizedBox(height: 16),

                      _buildActionButton(
                        context,
                        icon: Icons.add_task,
                        label: 'LOG ACTIVITY',
                        subtitle: 'Manual workout & event log',
                        color: AppTheme.primaryCyan,
                        onTap: () async {
                          await context.push('/log-activity');
                          _loadManualLoad(); // Refresh load after returning
                        },
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _manualLoad,
                                style: const TextStyle(
                                  color: AppTheme.primaryCyan,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'LOAD',
                                style: TextStyle(
                                  color: AppTheme.primaryCyan,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildActionButton(
                        context,
                        icon: Icons.insights,
                        label: 'READINESS SCORES',
                        subtitle: 'View all 18 calculated scores',
                        color: AppTheme.accentGreen,
                        onTap: () => context.push('/readiness'),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Sync Status Card
                      _buildSyncStatusCard(),

                      const SizedBox(height: 24),
                      
                      // Privacy Summary Card
                      _buildPrivacySummaryCard(),

                      const SizedBox(height: 20),
                      
                      // Status indicator
                      _buildStatusIndicator(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // AUIX Logo
          Image.asset(
            'assets/auix_logo.png',
            height: 50,
          ),
          const Spacer(),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textWhite),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textGray),
            onPressed: () {
              widget.session.setSignedIn(false, email: null);
              context.go('/login');
            },
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.favorite,
            label: 'HEART',
            value: _heartRate,
            unit: 'bpm',
            color: AppTheme.accentRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.insights,
            label: 'HRV',
            value: _hrv,
            unit: 'ms',
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.hotel,
            label: 'SLEEP',
            value: _sleep,
            unit: 'hrs',
            color: AppTheme.primaryCyan,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smallGlassCard(),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.titleStyle.copyWith(fontSize: 24, color: color),
          ),
          Text(
            unit,
            style: AppTheme.captionStyle.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.captionStyle.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCard(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.titleStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            Icon(Icons.arrow_forward_ios, color: AppTheme.textGray, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    if (_liveSync == null) return const SizedBox.shrink();

    return ValueListenableBuilder<String>(
      valueListenable: _liveSync!.lastStatus,
      builder: (context, status, _) {
        final isError = status == 'error' || status == 'permission_error';
        final isSyncing = status == 'syncing';
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard().copyWith(
            border: Border.all(
              color: isError ? AppTheme.accentRed.withOpacity(0.5) : AppTheme.primaryCyan.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.sync,
                    color: isError ? AppTheme.accentRed : AppTheme.primaryCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isError ? 'SYNC ISSUE' : 'HEALTH DATA SYNC',
                          style: AppTheme.titleStyle.copyWith(fontSize: 14),
                        ),
                        ValueListenableBuilder<DateTime?>(
                          valueListenable: _liveSync!.lastSyncAt,
                          builder: (context, lastSync, _) {
                            if (lastSync == null) return Text('Waiting for initial sync...', style: AppTheme.captionStyle);
                            return Text(
                              'Last synced: ${_formatTimeSince(lastSync)}',
                              style: AppTheme.captionStyle,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isSyncing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.primaryCyan)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppTheme.primaryCyan, size: 20),
                      onPressed: _handleManualSync,
                      tooltip: 'Sync Now',
                    ),
                ],
              ),
              if (isError) ...[
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: _liveSync!.lastError,
                  builder: (context, error, _) {
                    return Text(
                      error,
                      style: AppTheme.captionStyle.copyWith(color: AppTheme.accentRed, fontSize: 12),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleReconnectHealth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentRed.withOpacity(0.2),
                      foregroundColor: AppTheme.accentRed,
                      side: const BorderSide(color: AppTheme.accentRed),
                    ),
                    child: const Text('RECONNECT HEALTH'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleManualSync() async {
    if (_liveSync == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting manual sync...'), duration: Duration(seconds: 1)),
    );
    await _liveSync!.syncNow();
    _loadRealTimeStats();
  }

  Future<void> _handleReconnectHealth() async {
    final email = widget.session.email;
    if (email == null) return;

    // Reset authorized flag to force a new prompt
    await LocalSecureStore.instance.setHealthAuthorizedFor(email, false);
    
    // Trigger the prompt
    await _requestHealthPermissionsIfNeeded();
    
    // Restart sync
    if (_liveSync != null) {
      await _liveSync!.syncNow();
    }
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SYSTEM OPERATIONAL',
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.accentGreen,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }


  Widget _buildPrivacySummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.accentGreen, size: 24),
              const SizedBox(width: 12),
              Text('PRIVACY SUMMARY', style: AppTheme.titleStyle),
            ],
          ),
          const Divider(height: 24, color: AppTheme.glassBorder),
          _buildPrivacyItem(Icons.lock_person_outlined, 'Local Encryption', 'FIPS 140-2 compliant AES-256'),
          const SizedBox(height: 12),
          _buildPrivacyItem(Icons.cloud_off_outlined, 'Strictly Local', 'Raw metrics never leave this device'),
          const SizedBox(height: 12),
          _buildPrivacyItem(Icons.timer_outlined, 'Auto-Cleanup', 'Data expires after 30 days of inactivity'),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textGray),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: AppTheme.captionStyle.copyWith(fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
