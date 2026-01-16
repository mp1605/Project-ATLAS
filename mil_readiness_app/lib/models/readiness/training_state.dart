/// Training state from Banister impulse-response model
class TrainingState {
  final double fatigue; // F_t (fast decay state)
  final double fitness; // P_t (slow decay state)
  final double trainingEffect; // TE = P - F
  final DateTime date;

  const TrainingState({
    required this.fatigue,
    required this.fitness,
    required this.trainingEffect,
    required this.date,
  });

  Map<String, dynamic> toMap(String userEmail) {
    return {
      'user_email': userEmail,
      'date': date.millisecondsSinceEpoch,
      'fatigue': fatigue,
      'fitness': fitness,
      'training_effect': trainingEffect,
    };
  }

  static TrainingState fromMap(Map<String, dynamic> map) {
    return TrainingState(
      fatigue: (map['fatigue'] as num).toDouble(),
      fitness: (map['fitness'] as num).toDouble(),
      trainingEffect: (map['training_effect'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    );
  }

  @override
  String toString() {
    return 'TrainingState(F=$fatigue, P=$fitness, TE=$trainingEffect)';
  }
}
