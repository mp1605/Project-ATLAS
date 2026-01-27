import '../models/comprehensive_readiness_result.dart';

class InsightGenerator {
  /// Generates a single calm sentence describing today's readiness context
  static String getDailyInsight(List<ComprehensiveReadinessResult> trend) {
    if (trend.length < 2) return "Establishing your operational baseline metrics.";
    
    final latest = trend.last;
    final previous = trend[trend.length - 2];
    final delta = latest.overallReadiness - previous.overallReadiness;
    
    // Check specific critical metrics
    if (latest.sleepIndex < 60 && latest.sleepDebt > 2) {
      return "Accumulated sleep debt is impacting cognitive recovery.";
    }
    
    if (latest.recoveryScore < previous.recoveryScore && latest.fatigueIndex > 70) {
      return "Recovery indicators are lagging behind recent activity loads.";
    }
    
    if (latest.stressLoad > 80) {
      return "Elevated physiological stress detected; monitor recovery efficiency.";
    }

    if (delta > 5) return "Readiness is improving; recent recovery periods have been effective.";
    if (delta < -5) return "Slight decline in readiness; prioritize sleep consistency tonight.";
    
    return "Readiness is stable; consistent baseline maintained.";
  }

  /// Generates a one-line interpretation for the hero card
  static String getSummaryInterpretation(ComprehensiveReadinessResult result, List<ComprehensiveReadinessResult> trend) {
    if (trend.length < 2) return "Waiting for multi-day data for trend analysis.";
    
    final latest = result.overallReadiness;
    final avg = trend.map((e) => e.overallReadiness).reduce((a, b) => a + b) / trend.length;
    
    if (latest < avg - 5) return "Current metrics are trending below your 7-day baseline.";
    if (latest > avg + 5) return "Operational capacity is currently above recent averages.";
    
    return "Physiological markers are aligned with your recent baseline.";
  }

  /// Map score to tactical status labels
  static String getStatusLabel(double score) {
    if (score >= 80) return "GO";
    if (score >= 60) return "CAUTION";
    return "NO-GO";
  }

  /// Calculate trend direction and duration
  static String getTrendLabel(List<ComprehensiveReadinessResult> trend) {
    if (trend.length < 3) return "Stable";
    
    int consecutive = 1;
    bool increasing = trend.last.overallReadiness > trend[trend.length - 2].overallReadiness;
    
    for (int i = trend.length - 2; i > 0; i--) {
      bool currentIncreasing = trend[i].overallReadiness > trend[i - 1].overallReadiness;
      if (currentIncreasing == increasing) {
        consecutive++;
      } else {
        break;
      }
    }
    
    final arrow = increasing ? "↑" : "↓";
    return "Readiness trend: $arrow $consecutive days";
  }
}
