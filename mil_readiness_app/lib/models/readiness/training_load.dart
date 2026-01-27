/// Training load and TRIMP data
class TrainingLoad {
  final double trimp; // Combined Training Impulse score (auto + manual)
  final int workoutMinutes;
  final double averageHeartRate;
  final double maxHeartRateUsed;
  final double restingHeartRate;
  final double manualLoad; // Load from manual activity entries
  final double autoLoad; // Load from auto-detected HR data

  const TrainingLoad({
    required this.trimp,
    required this.workoutMinutes,
    required this.averageHeartRate,
    required this.maxHeartRateUsed,
    required this.restingHeartRate,
    this.manualLoad = 0,
    this.autoLoad = 0,
  });

  /// Check if load includes manual entries
  bool get hasManualLoad => manualLoad > 0;

  /// Check if load includes auto-detected data
  bool get hasAutoLoad => autoLoad > 0;

  @override
  String toString() {
    return 'TrainingLoad(TRIMP=${trimp.toStringAsFixed(1)}, duration=${workoutMinutes}min, '
           'manual=${manualLoad.toStringAsFixed(1)}, auto=${autoLoad.toStringAsFixed(1)})';
  }
}
