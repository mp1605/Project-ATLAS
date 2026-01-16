/// Training load and TRIMP data
class TrainingLoad {
  final double trimp; // Training Impulse score
  final int workoutMinutes;
  final double averageHeartRate;
  final double maxHeartRateUsed;
  final double restingHeartRate;

  const TrainingLoad({
    required this.trimp,
    required this.workoutMinutes,
    required this.averageHeartRate,
    required this.maxHeartRateUsed,
    required this.restingHeartRate,
  });

  @override
  String toString() {
    return 'TrainingLoad(TRIMP=$trimp, duration=${workoutMinutes}min, '
           'avgHR=$averageHeartRate)';
  }
}
