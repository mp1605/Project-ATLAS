import 'dart:math';

/// Sleep quality score breakdown (0-100 for each component)
class SleepScore {
  final double totalScore; // 0-100
  final double duration;   // 0-100 (adequacy)
  final double stages;     // 0-100 (deep + REM ratio)
  final double fragmentation; // 0-100 (lower awake time = better)
  final double regularity;  // 0-100 (consistent timing)
  
  // Raw components for debugging
  final double totalSleepHours;
  final double deepMinutes;
  final double remMinutes;
  final double awakeMinutes;
  final DateTime sleepMidpoint;
  
  // Source of sleep data ('auto', 'manual', or 'none')
  final String source;

  const SleepScore({
    required this.totalScore,
    required this.duration,
    required this.stages,
    required this.fragmentation,
    required this.regularity,
    required this.totalSleepHours,
    required this.deepMinutes,
    required this.remMinutes,
    required this.awakeMinutes,
    required this.sleepMidpoint,
    this.source = 'auto',
  });

  /// Check if sleep data came from manual entry
  bool get isManual => source == 'manual';

  @override
  String toString() {
    return 'SleepScore(total=${totalScore.toStringAsFixed(1)}, source=$source, '
           'duration=${duration.toStringAsFixed(0)}, stages=${stages.toStringAsFixed(0)})';
  }
}
