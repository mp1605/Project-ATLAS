/// Readiness category (Go/Caution/No-Go)
enum ReadinessCategory {
  go,      // Ready for high-intensity work
  caution, // Moderate activity recommended
  noGo,    // Rest/recovery day
}

/// Component scores breakdown
class ComponentScores {
  final double recovery;
  final double sleep;
  final double fitness;
  final double fatigueImpact; // How much fatigue is reducing readiness

  const ComponentScores({
    required this.recovery,
    required this.sleep,
    required this.fitness,
    required this.fatigueImpact,
  });
}

/// Complete readiness calculation result
class ReadinessResult {
  final double readiness; // 0-100 (F1)
  final double physical;  // 0-100 (F2)
  final ReadinessCategory category;
  final ComponentScores components;
  final double illnessProbability;
  final double illnessPenalty;
  final DateTime date;

  const ReadinessResult({
    required this.readiness,
    required this.physical,
    required this.category,
    required this.components,
    required this.illnessProbability,
    required this.illnessPenalty,
    required this.date,
  });

  @override
  String toString() {
    return 'ReadinessResult(READ=$readiness, PHYS=$physical, category=$category)';
  }
}
