import '../repositories/manual_activity_repository.dart';
import '../models/manual_activity_entry.dart';

/// Service for calculating training load from manual activity entries
/// 
/// Converts RPE-based manual entries to TRIMP-equivalent load values
/// that can be combined with auto-detected workout data.
class ManualLoadService {
  /// Activity type multipliers for load calculation
  /// Higher intensity activities get higher multipliers
  static const Map<ActivityType, double> _activityMultipliers = {
    ActivityType.running: 1.2,
    ActivityType.hiitCircuit: 1.3,
    ActivityType.combatTraining: 1.3,
    ActivityType.ptTest: 1.4,
    ActivityType.swimming: 1.1,
    ActivityType.cycling: 1.0,
    ActivityType.ruckMarch: 1.25,
    ActivityType.strengthTraining: 0.9,
    ActivityType.hiking: 0.8,
    ActivityType.sportsGeneral: 1.0,
    ActivityType.walking: 0.6,
    ActivityType.manualLabor: 0.85,
    ActivityType.mobilityStretching: 0.4,
    ActivityType.yogaBreathwork: 0.5,
    ActivityType.other: 1.0,
  };

  /// Heat level multipliers (environmental stress)
  static const Map<HeatLevel, double> _heatMultipliers = {
    HeatLevel.cool: 0.95,
    HeatLevel.normal: 1.0,
    HeatLevel.hot: 1.15,
    HeatLevel.veryHot: 1.30,
  };

  /// Calculate total manual training load for a specific date
  /// 
  /// Returns TRIMP-equivalent value based on:
  /// - Duration (minutes)
  /// - RPE (1-10 scale)
  /// - Activity type multiplier
  /// - Heat/environmental multiplier
  /// - Load/weight carried (if applicable)
  static Future<ManualLoadResult> calculateForDate({
    required String userEmail,
    required DateTime date,
  }) async {
    final repo = ManualActivityRepository();
    final entries = await repo.listForDay(userEmail: userEmail, dayLocal: date);

    if (entries.isEmpty) {
      return ManualLoadResult(
        totalLoad: 0,
        activityCount: 0,
        totalMinutes: 0,
        entries: [],
      );
    }

    double totalLoad = 0;
    int totalMinutes = 0;

    for (final entry in entries) {
      final load = _calculateEntryLoad(entry);
      totalLoad += load;
      totalMinutes += entry.durationMinutes;
    }

    print('📊 Manual load for ${date.toLocal()}: ${totalLoad.toStringAsFixed(1)} TRIMP-eq from ${entries.length} activities');

    return ManualLoadResult(
      totalLoad: totalLoad,
      activityCount: entries.length,
      totalMinutes: totalMinutes,
      entries: entries,
    );
  }

  /// Calculate load for a single activity entry
  /// 
  /// Formula: Load = duration * (RPE / 10) * activityMultiplier * heatMultiplier * loadMultiplier
  static double _calculateEntryLoad(ManualActivityEntry entry) {
    // Base load: duration * normalized RPE (0-1)
    final baseLoad = entry.durationMinutes * (entry.rpe / 10.0);

    // Activity type multiplier
    final activityMult = _activityMultipliers[entry.activityType] ?? 1.0;

    // Heat/environmental multiplier
    final heatMult = entry.heatLevel != null 
        ? _heatMultipliers[entry.heatLevel] ?? 1.0 
        : 1.0;

    // Load/weight carried multiplier (for ruck marches, strength training)
    double loadMult = 1.0;
    if (entry.loadValue != null && entry.loadValue! > 0) {
      // Every 10kg/20lb adds ~5% load
      final weightKg = entry.loadUnit == 'lb' 
          ? entry.loadValue! * 0.453592 
          : entry.loadValue!;
      loadMult = 1.0 + (weightKg / 200); // 10kg = 5% increase
    }

    // Feel-after adjustment
    double feelMult = 1.0;
    switch (entry.feelAfter) {
      case 'worse':
        feelMult = 1.15; // Harder effort than expected
        break;
      case 'better':
        feelMult = 0.90; // Easier than expected
        break;
      default:
        feelMult = 1.0;
    }

    final totalLoad = baseLoad * activityMult * heatMult * loadMult * feelMult;
    
    return totalLoad;
  }

  /// Get weekly load summary
  static Future<WeeklyLoadSummary> getWeeklyLoad({
    required String userEmail,
    required DateTime endDate,
  }) async {
    double totalLoad = 0;
    int totalActivities = 0;
    int totalMinutes = 0;
    final dailyLoads = <DateTime, double>{};

    for (int i = 0; i < 7; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dayResult = await calculateForDate(userEmail: userEmail, date: date);
      
      totalLoad += dayResult.totalLoad;
      totalActivities += dayResult.activityCount;
      totalMinutes += dayResult.totalMinutes;
      dailyLoads[date] = dayResult.totalLoad;
    }

    return WeeklyLoadSummary(
      totalLoad: totalLoad,
      averageDailyLoad: totalLoad / 7,
      totalActivities: totalActivities,
      totalMinutes: totalMinutes,
      dailyLoads: dailyLoads,
    );
  }
}

/// Result of manual load calculation for a single day
class ManualLoadResult {
  final double totalLoad;
  final int activityCount;
  final int totalMinutes;
  final List<ManualActivityEntry> entries;

  ManualLoadResult({
    required this.totalLoad,
    required this.activityCount,
    required this.totalMinutes,
    required this.entries,
  });
}

/// Weekly load summary
class WeeklyLoadSummary {
  final double totalLoad;
  final double averageDailyLoad;
  final int totalActivities;
  final int totalMinutes;
  final Map<DateTime, double> dailyLoads;

  WeeklyLoadSummary({
    required this.totalLoad,
    required this.averageDailyLoad,
    required this.totalActivities,
    required this.totalMinutes,
    required this.dailyLoads,
  });
}
