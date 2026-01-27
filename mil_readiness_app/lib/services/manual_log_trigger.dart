import '../services/live_sync_controller.dart';

/// Triggers automatic UI refresh after manual log submission
class ManualLogTrigger {
  /// Trigger UI refresh after manual log submission
  /// 
  /// This should be called after:
  /// - Manual sleep entry
  /// - Manual activity entry
  /// - Manual hydration/nutrition/stress log
  /// 
  /// Note: Scores will be recalculated on the next scheduled sync.
  /// For immediate recalculation, use the "Sync Now" button in the app.
  static Future<void> recalculateScores({
    required DateTime date,
  }) async {
    try {
      print('🔄 Triggering UI refresh for manual log submission...');
      
      // Trigger LiveSync to update UI
      // This will fetch the latest data and recalculate scores
      final controller = LiveSyncController();
      await controller.performSync();
      
      print('✅ UI refresh triggered');
      
    } catch (e) {
      print('❌ Error triggering UI refresh: $e');
      // Don't throw - we don't want to block the user's logging action
    }
  }
  
  /// Trigger UI refresh for today
  static Future<void> recalculateToday() async {
    await recalculateScores(date: DateTime.now());
  }
}
