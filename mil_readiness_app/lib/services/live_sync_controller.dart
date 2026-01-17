import 'dart:async';
import 'package:flutter/foundation.dart';

import 'local_secure_store.dart';
import '../database/health_data_repository.dart';
import '../adapters/health_data_adapter.dart';

class LiveSyncController {
  LiveSyncController({
    required HealthDataAdapter healthAdapter,
    required LocalSecureStore store,
    required String email,
    Duration window = const Duration(minutes: 10),
    Duration interval = const Duration(seconds: 60),
  })  : _healthAdapter = healthAdapter,
        _store = store,
        _email = email,
        window = window,
        interval = interval {
    print('🔄 LiveSyncController: Initialized for $_email');
    print('   Interval: ${interval.inSeconds}s, Window: ${window.inMinutes}min');
  }

  final HealthDataAdapter _healthAdapter;
  final LocalSecureStore _store;
  final String _email;

  final Duration interval;
  final Duration window;

  Timer? _timer;
  bool _running = false;
  bool _busyTick = false;

  int _successCount = 0;
  int _failureCount = 0;
  int _totalDataPoints = 0;

  final ValueNotifier<DateTime?> lastSyncAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String> lastStatus = ValueNotifier<String>('idle');
  final ValueNotifier<String> lastError = ValueNotifier<String>('');
  final ValueNotifier<int> dataPointCount = ValueNotifier<int>(0);

  Future<void> start() async {
    if (_running) {
      print('⚠️ LiveSyncController: Already running, ignoring start()');
      return;
    }
    _running = true;
    print('▶️ LiveSyncController: Starting for $_email...');

    final prevAt = await _store.getHealthLastSyncAtFor(_email);
    final prevStatus = await _store.getHealthLastSyncStatusFor(_email);

    if (prevAt != null) {
      lastSyncAt.value = prevAt;
      print('   Previous sync: $prevAt');
    }
    if (prevStatus != null) {
      lastStatus.value = prevStatus;
      print('   Previous status: $prevStatus');
    }

    print('🔄 LiveSyncController: Running initial sync...');
    await _tick();
    
    print('⏰ LiveSyncController: Starting periodic timer (${interval.inSeconds}s)');
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    print('⏸️ LiveSyncController: Stopped');
    print('   Stats - Success: $_successCount, Failures: $_failureCount, Total points: $_totalDataPoints');
  }

  Future<void> syncNow() async {
    print('🔄 LiveSyncController: Manual sync requested');
    await _tick();
  }

  Future<void> _tick() async {
    if (_email.isEmpty) {
      print('⚠️ LiveSyncController: Skipping tick - no email');
      return;
    }
    if (_busyTick) {
      print('⚠️ LiveSyncController: Skipping tick - already in progress');
      return;
    }
    _busyTick = true;

    final tickStartTime = DateTime.now();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔄 LiveSync TICK at ${tickStartTime.toLocal()}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    lastStatus.value = 'syncing';

    try {
      final now = DateTime.now();

      // SMART WINDOW: Calculate actual window needed to bridge the gap
      final prevSyncAt = await _store.getHealthLastSyncAtFor(_email);
      final metricsCount = await HealthDataRepository.countUserMetrics(_email);
      
      Duration windowToUse = window; // Default (e.g. 10 mins)
      
      if (prevSyncAt == null || metricsCount == 0) {
        // Step 0: Initial sync or empty database - fetch last 7 days of history
        windowToUse = const Duration(days: 7);
        print('🌟 DEEP SYNC: Fetching last 7 days of history for $_email (Metrics count: $metricsCount)');
      } else {
        // Step 0: Incremental sync - bridge the gap since last success
        final gap = now.difference(prevSyncAt);
        if (gap > window) {
          // Cap at 30 days to avoid performance issues
          final cappedGap = gap.inDays > 30 ? const Duration(days: 30) : gap;
          windowToUse = cappedGap + const Duration(minutes: 5); // Add buffer
          print('📏 GAP SYNC: Expanding window to ${windowToUse.inMinutes} mins to bridge since $prevSyncAt');
        } else {
          print('⏱️ NORMAL SYNC: Using default ${window.inMinutes} min window');
        }
      }

      // iOS Privacy Note: hasPermissions() is unreliable on iOS - it returns false
      // even when permissions are granted (Apple privacy feature).
      // So we skip it and attempt to read data directly instead.
      
      print('📋 Step 1/2: Attempting to read health data...');
      
      // Try to read data - this is the ONLY reliable way to verify iOS Health access
      final dataPoints = await _healthAdapter.getMetrics(window: windowToUse);
      
      // Always update check timestamp
      await _store.setHealthAuthCheckedAtFor(_email, now);
      
      // If we got here without exception, we have access
      final hasData = dataPoints.isNotEmpty;
      print('✅ Step 1: Data read ${hasData ? 'successful' : 'returned no data'} (${dataPoints.length} points)');
      
      // Store that we have access (since read succeeded)
      await _store.setHealthAuthorizedFor(_email, true);

      // Step 2: Store in encrypted database
      if (dataPoints.isNotEmpty) {
        print('💾 Step 2/3: Storing ${dataPoints.length} metrics in encrypted database...');
        
        // Adapter already returns HealthMetric objects, use directly
        final stored = await HealthDataRepository.insertHealthMetrics(_email, dataPoints);
        print('✅ Stored $stored encrypted metrics in database');
        
        // Update sync status in database
        await HealthDataRepository.updateSyncStatus(
          userEmail: _email,
          status: 'ok',
          wearableType: _healthAdapter.deviceType,
        );
      }

      // Step 3: Update in-memory state
      print('📊 Step 3/3: Updating sync state...');
      lastSyncAt.value = now;
      lastStatus.value = 'ok';
      lastError.value = '';
      dataPointCount.value = dataPoints.length;
      _totalDataPoints += dataPoints.length;

      await _store.setHealthLastSyncAtFor(_email, now);
      await _store.setHealthLastSyncStatusFor(_email, 'ok');
      
      _successCount++;
      print('✅ Step 3: State updated successfully');
      
      final duration = DateTime.now().difference(tickStartTime);
      print('');
      print('✅ SYNC SUCCESSFUL');
      print('   Duration: ${duration.inMilliseconds}ms');
      print('   Data points: ${dataPoints.length}');
      print('   Session stats: ${_successCount} successes, ${_failureCount} failures');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } catch (e, stackTrace) {
      _failureCount++;
      
      print('');
      print('❌ SYNC FAILED');
      print('   Error: $e');
      print('   Stack trace:');
      print('$stackTrace');
      
      // Categorize error for better user messaging
      String userMessage;
      if (e.toString().contains('permission') || e.toString().contains('denied')) {
        userMessage = 'Health data access denied. Check Settings → Privacy → Health.';
        lastStatus.value = 'permission_error';
      } else if (e.toString().contains('not available') || e.toString().contains('not supported')) {
        userMessage = 'HealthKit not available on this device (are you on simulator?).';
        lastStatus.value = 'not_available';
      } else {
        userMessage = 'Error: ${e.toString()}';
        lastStatus.value = 'error';
      }
      
      lastError.value = userMessage;
      await _store.setHealthLastSyncStatusFor(_email, lastStatus.value);
      
      print('   User message: $userMessage');
      print('   Session stats: ${_successCount} successes, ${_failureCount} failures');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
    } finally {
      _busyTick = false;
    }
  }

  // Expose stats for debugging
  Map<String, dynamic> getStats() {
    return {
      'running': _running,
      'success_count': _successCount,
      'failure_count': _failureCount,
      'total_data_points': _totalDataPoints,
      'success_rate': _successCount + _failureCount > 0 
          ? (_successCount / (_successCount + _failureCount) * 100).toStringAsFixed(1) + '%'
          : 'N/A',
    };
  }
}
