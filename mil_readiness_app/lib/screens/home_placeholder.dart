import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../routes.dart';
import '../database/secure_database_manager.dart';
import '../services/local_secure_store.dart';
import '../services/live_sync_controller.dart';
import '../services/last_sleep_service.dart';
import '../adapters/health_adapter_factory.dart';
import '../models/wearable_type.dart';

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

    print('🔍 Starting permission check for $email...');

    try {
      final adapter = HealthAdapterFactory.createAdapter(WearableType.appleWatch);
      
      // Check actual iOS permission status
      print('  → Checking iOS permission status...');
      final hasPerms = await adapter.hasPermissions();
      print('  → iOS hasPermissions result: $hasPerms');
      
      if (hasPerms) {
        // We have permissions - update stored flag and continue
        await LocalSecureStore.instance.setHealthAuthorizedFor(email, true);
        print('✅ Health permissions already granted by iOS');
        return;
      }

      // iOS doesn't have permissions - ALWAYS show dialog on fresh login
      // (Don't check stored flag because it persists after app deletion)
      print('🔐 iOS permissions NOT granted - showing permission dialog...');
      
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

      // Get LATEST SLEEP SESSION (not SUM!) using LastSleepService
      final lastSleep = await LastSleepService.getLastSleep(widget.session.email!);

      if (mounted) {
        setState(() {
          if (hrResults.isNotEmpty && hrResults.first['value'] != null) {
            _heartRate = hrResults.first['value'].toString().split('.')[0];
            _lastUpdated = DateTime.fromMillisecondsSinceEpoch(hrResults.first['timestamp'] as int);
          }
          if (hrvResults.isNotEmpty && hrvResults.first['value'] != null) {
            _hrv = hrvResults.first['value'].toString().split('.')[0];
          }
          if (lastSleep != null) {
            final hours = lastSleep.totalMinutes / 60.0;
            _sleep = hours.toStringAsFixed(1);
          }
        });
        print('  ✅ Stats updated: HR=$_heartRate, HRV=$_hrv, Sleep=$_sleep');
        if (_lastUpdated != null) {
          print('  ⏰ Last heart rate measurement: ${_lastUpdated!.toLocal()}');
        }
      }
    } catch (e) {
      print('❌ Error loading stats: $e');
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
                        icon: Icons.insights,
                        label: 'READINESS SCORES',
                        subtitle: 'View all 18 calculated scores',
                        color: AppTheme.accentGreen,
                        onTap: () => context.push('/readiness'),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Sync Status Card
                      _buildSyncStatusCard(),

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
}
