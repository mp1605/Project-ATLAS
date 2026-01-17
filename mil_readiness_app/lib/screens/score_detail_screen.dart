import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Detail screen showing the breakdown of a specific readiness score
class ScoreDetailScreen extends StatelessWidget {
  final String scoreName;
  final double scoreValue;
  final Map<String, dynamic> components;
  final String confidence;

  const ScoreDetailScreen({
    super.key,
    required this.scoreName,
    required this.scoreValue,
    required this.components,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$scoreName Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Score Card
                _buildMainScoreCard(),
                
                const SizedBox(height: 32),
                
                Text(
                  'COMPONENTS',
                  style: AppTheme.headingStyle.copyWith(fontSize: 18, color: AppTheme.primaryCyan),
                ),
                const SizedBox(height: 16),
                
                // Component Breakdown
                if (components.isEmpty)
                  Center(child: Text('No detailed breakdown available', style: AppTheme.captionStyle))
                else
                  ...components.entries.map((e) => _buildComponentRow(e.key, e.value)).toList(),
                
                const SizedBox(height: 40),
                
                // Confidence & Interpretation
                _buildInterpretationCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _getScoreColor(scoreValue).withOpacity(0.5), width: 4),
            ),
            child: Center(
              child: Text(
                scoreValue.toStringAsFixed(0),
                style: AppTheme.headingStyle.copyWith(
                  fontSize: 32,
                  color: _getScoreColor(scoreValue),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scoreName.toUpperCase(),
                  style: AppTheme.titleStyle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(confidence).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CONFIDENCE: ${confidence.toUpperCase()}',
                    style: TextStyle(
                      color: _getConfidenceColor(confidence),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentRow(String label, dynamic rawValue) {
    final value = (rawValue is num) ? rawValue.toDouble() : 0.0;
    
    // Normalize label: sleep_asleep -> Sleep Asleep
    final normalizedLabel = label.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ');
    
    // Most components are 0-100, but some might be raw units
    final isPercentage = value >= 0 && value <= 100;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(normalizedLabel, style: AppTheme.titleStyle.copyWith(fontSize: 14)),
              Text(
                value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                style: AppTheme.titleStyle.copyWith(fontSize: 14, color: AppTheme.primaryCyan),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isPercentage ? (value / 100).clamp(0, 1) : 0.5,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryCyan.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smallGlassCard().copyWith(
        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.accentGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'INSIGHT',
                style: AppTheme.titleStyle.copyWith(fontSize: 14, color: AppTheme.accentGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getInterpretation(),
            style: AppTheme.captionStyle.copyWith(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _getInterpretation() {
    if (scoreName.contains('Sleep')) {
      if (scoreValue >= 80) return 'Your sleep quality is excellent. Both duration and stage distribution (Deep/REM) are optimal for recovery.';
      if (scoreValue >= 60) return 'Good sleep coverage, but check if light sleep or awake time was high. Consistency is key for readiness.';
      return 'Sleep was insufficient or fragmented. Priority should be given to recovery and cognitive load management today.';
    }
    if (scoreName.contains('Recovery')) {
      if (scoreValue >= 80) return 'Physiological state indicates full recovery. High-intensity training or mission tasks are recommended.';
      return 'Moderate physiological strain detected. Watch for trends in Heart Rate Variability and resting pulse.';
    }
    return 'This score is calculated based on recent trends in your health data compared to your historical 28-day baseline.';
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return AppTheme.accentGreen;
    if (score >= 50) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }

  Color _getConfidenceColor(String conf) {
    if (conf == 'high') return AppTheme.accentGreen;
    if (conf == 'medium') return AppTheme.primaryBlue;
    return AppTheme.accentRed;
  }
}
