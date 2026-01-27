import '../models/comprehensive_readiness_result.dart';

/// Generates brief, actionable insights for "Why today's score"
/// Maximum 3 items, based on most impactful factors
class ReadinessInsightService {
  /// Generate top 3 factors affecting today's readiness score
  /// Returns human-readable insights without exposing internal weights or equations
  static List<String> generateTopFactors(
    ComprehensiveReadinessResult current,
    List<ComprehensiveReadinessResult> trend,
  ) {
    final insights = <_ScoredInsight>[];
    
    // Compare to recent average
    final recentAvg = trend.isEmpty 
      ? null 
      : trend.map((e) => e.overallReadiness).reduce((a, b) => a + b) / trend.length;
    
    // Sleep analysis
    if (current.sleepIndex < 60) {
      insights.add(_ScoredInsight(
        text: 'Sleep quality below optimal range',
        impact: (70 - current.sleepIndex).abs(),
      ));
    } else if (current.sleepIndex > 85) {
      insights.add(_ScoredInsight(
        text: 'Excellent sleep quality detected',
        impact: 15,
      ));
    }
    
    // Recovery analysis
    if (current.recoveryScore < 65) {
      insights.add(_ScoredInsight(
        text: 'Recovery indicators below baseline',
        impact: (70 - current.recoveryScore).abs(),
      ));
    }
    
    // Fatigue analysis
    if (current.fatigueIndex > 70) {
      insights.add(_ScoredInsight(
        text: 'Elevated fatigue load detected',
        impact: (current.fatigueIndex - 60).abs(),
      ));
    }
    
    // Stress analysis
    if (current.stressLoad > 75) {
      insights.add(_ScoredInsight(
        text: 'Physiological stress above normal',
        impact: (current.stressLoad - 60).abs(),
      ));
    }
    
    // Injury risk
    if (current.injuryRisk > 70) {
      insights.add(_ScoredInsight(
        text: 'Injury risk elevated - monitor movement',
        impact: (current.injuryRisk - 50).abs(),
      ));
    }
    
    // Activity balance
    if (current.dailyActivity < 50) {
      insights.add(_ScoredInsight(
        text: 'Activity levels below target',
        impact: (60 - current.dailyActivity).abs(),
      ));
    }
    
    // Trend-based insights
    if (recentAvg != null) {
      final delta = current.overallReadiness - recentAvg;
      if (delta > 10) {
        insights.add(_ScoredInsight(
          text: 'Trending upward over past 7 days',
          impact: 12,
        ));
      } else if (delta < -10) {
        insights.add(_ScoredInsight(
          text: 'Metrics declining from recent baseline',
          impact: 12,
        ));
      }
    }
    
    // If no negative insights, highlight positive aspects
    if (insights.isEmpty || insights.every((i) => i.impact < 10)) {
      if (current.overallReadiness >= 80) {
        insights.add(_ScoredInsight(
          text: 'All systems within optimal range',
          impact: 20,
        ));
      } else if (current.overallReadiness >= 70) {
        insights.add(_ScoredInsight(
          text: 'Baseline metrics stable',
          impact: 10,
        ));
      }
    }
    
    // Sort by impact and return top 3
    insights.sort((a, b) => b.impact.compareTo(a.impact));
    return insights.take(3).map((i) => i.text).toList();
  }
  
  /// Calculate data confidence level based on data completeness
  /// Returns: 'High', 'Medium', or 'Low'
  static String calculateDataConfidence(
    ComprehensiveReadinessResult result,
    List<ComprehensiveReadinessResult> trend,
  ) {
    int confidenceScore = 0;
    
    // Trend history (0-40 points)
    if (trend.length >= 7) {
      confidenceScore += 40;
    } else if (trend.length >= 4) {
      confidenceScore += 25;
    } else if (trend.length >= 2) {
      confidenceScore += 10;
    }
    
    // Score quality indicators (0-60 points)
    final highConfidenceScores = [
      result.sleepIndex,
      result.recoveryScore,
      result.fatigueIndex,
      result.overallReadiness,
    ].where((s) => s > 0).length;
    
    confidenceScore += (highConfidenceScores * 15).clamp(0, 60);
    
    // Map to label
    if (confidenceScore >= 85) return 'High';
    if (confidenceScore >= 50) return 'Medium';
    return 'Low';
  }
  
  /// Get a brief explanation of confidence level
  static String getConfidenceExplanation(String confidence) {
    switch (confidence) {
      case 'High':
        return 'Complete data coverage with established baseline';
      case 'Medium':
        return 'Sufficient data for reliable calculation';
      case 'Low':
        return 'Limited historical data - building baseline';
      default:
        return 'Unknown confidence level';
    }
  }
}

/// Internal class for scoring insights
class _ScoredInsight {
  final String text;
  final double impact;
  
  _ScoredInsight({required this.text, required this.impact});
}
