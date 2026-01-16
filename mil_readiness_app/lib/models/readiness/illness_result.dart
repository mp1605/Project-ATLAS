/// Illness detection result with probability and penalty
class IllnessResult {
  final double probability; // 0-1 probability of illness/strain
  final double penalty; // 0-30 point penalty for readiness
  final bool isHigh; // true if p > 0.65 (high risk)
  
  // Component z-scores for debugging
  final double zHRV;
  final double zRHR;
  final double zRR;
  final double hypoxiaMetric;

  const IllnessResult({
    required this.probability,
    required this.penalty,
    required this.isHigh,
    required this.zHRV,
    required this.zRHR,
    required this.zRR,
    required this.hypoxiaMetric,
  });

  @override
  String toString() {
    return 'IllnessResult(p=$probability, penalty=$penalty, high=$isHigh)';
  }
}
