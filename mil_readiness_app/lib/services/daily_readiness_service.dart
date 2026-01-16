import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../algorithms/readiness_calculator.dart';
import '../database/readiness_score_repository.dart';
import '../services/local_secure_store.dart';
import '../services/data_availability_checker.dart';

/// Background task dispatcher for workmanager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('🌙 Background task started: $task');
      
      switch (task) {
        case 'daily_readiness_calculation':
          await _calculateDailyReadiness();
          break;
        case 'backfill_scores':
          final daysBack = inputData?['days_back'] as int? ?? 30;
          await _backfillScores(daysBack);
          break;
      }
      
      print('✅ Background task completed: $task');
      return Future.value(true);
    } catch (e) {
      print('❌ Background task failed: $e');
      return Future.value(false);
    }
  });
}

/// Calculate yesterday's readiness score (at midnight, data is complete)
Future<void> _calculateDailyReadiness() async {
  final yesterday = DateTime.now().subtract(Duration(days: 1));
  
  // Get active user
  final email = await LocalSecureStore.instance.getActiveSessionEmail();
  if (email == null) {
    print('⚠️ No active user for background calculation');
    return;
  }

  // Check if already calculated
  final exists = await ReadinessScoreRepository.hasScoreForDate(
    userEmail: email,
    date: yesterday,
  );
  
  if (exists) {
    print('ℹ️ Score for ${yesterday.toLocal()} already calculated');
    return;
  }

  // Check data availability
  final dataCheck = await DataAvailabilityChecker.check(email);
  if (!dataCheck.canCalculateReadiness) {
    print('⚠️ Not enough data for readiness calculation yet');
    return;
  }

  // Calculate readiness
  final result = await ReadinessCalculator.calculate(
    userEmail: email,
    date: yesterday,
    userAge: 30, // TODO: Get from user profile
  );

  if (result != null) {
    await ReadinessScoreRepository.store(
      userEmail: email,
      date: yesterday,
      result: result,
    );
    
    print('✅ Background calculated readiness for ${yesterday.toLocal()}: ${result.readiness.toStringAsFixed(0)}');
  }
}

/// Backfill scores for past days
Future<void> _backfillScores(int daysBack) async {
  final email = await LocalSecureStore.instance.getActiveSessionEmail();
  if (email == null) return;

  final end = DateTime.now();
  final start = end.subtract(Duration(days: daysBack));
  
  for (var date = start; 
       date.isBefore(end); 
       date = date.add(Duration(days: 1))) {
    
    // Check if already calculated
    final exists = await ReadinessScoreRepository.hasScoreForDate(
      userEmail: email,
      date: date,
    );
    
    if (exists) continue;

    // Try to calculate
    try {
      final result = await ReadinessCalculator.calculate(
        userEmail: email,
        date: date,
        userAge: 30,
      );
      
      if (result != null) {
        await ReadinessScoreRepository.store(
          userEmail: email,
          date: date,
          result: result,
        );
        
        print('📊 Backfilled score for ${date.toLocal()}');
      }
    } catch (e) {
      print('⚠️ Could not calculate for ${date.toLocal()}: $e');
    }
  }
}

/// Daily readiness scoring service
class DailyReadinessService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );
    
    await scheduleDailyCalculation();
    
    print('✅ Daily readiness service initialized');
  }

  /// Schedule daily calculation at 2 AM
  static Future<void> scheduleDailyCalculation() async {
    await Workmanager().registerPeriodicTask(
      'daily_readiness',
      'daily_readiness_calculation',
      frequency: Duration(hours: 24),
      initialDelay: _calculateInitialDelay(),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
      ),
    );
    
    print('✅ Scheduled daily readiness calculation');
  }

  /// Calculate delay until 2 AM
  static Duration _calculateInitialDelay() {
    final now = DateTime.now();
    var next2AM = DateTime(now.year, now.month, now.day, 2, 0);
    
    // If past 2 AM today, schedule for tomorrow
    if (now.isAfter(next2AM)) {
      next2AM = next2AM.add(Duration(days: 1));
    }
    
    final delay = next2AM.difference(now);
    print('ℹ️ Next calculation scheduled for: ${next2AM.toLocal()}');
    
    return delay;
  }

  /// Trigger immediate backfill
  static Future<void> backfillPastScores({int daysBack = 30}) async {
    await Workmanager().registerOneOffTask(
      'backfill_${DateTime.now().millisecondsSinceEpoch}',
      'backfill_scores',
      inputData: {'days_back': daysBack},
    );
    
    print('✅ Started backfill for last $daysBack days');
  }

  /// Cancel all scheduled tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    print('✅ Cancelled all background tasks');
  }
}
