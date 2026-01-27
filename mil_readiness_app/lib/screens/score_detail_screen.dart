import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/insight_generator.dart';

/// Elevated Detail screen showing the breakdown of a specific readiness score
class ScoreDetailScreen extends StatefulWidget {
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
  State<ScoreDetailScreen> createState() => _ScoreDetailScreenState();
}

class _ScoreDetailScreenState extends State<ScoreDetailScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final tacticalStatus = InsightGenerator.getStatusLabel(widget.scoreValue);
    final color = _getScoreColor(widget.scoreValue);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scoreName.toUpperCase()} ANALYTICS'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => HapticFeedback.mediumImpact(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Score Card with Animation
                _buildMainScoreCard(tacticalStatus, color),
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: AppTheme.primaryCyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'COMPONENT BREAKDOWN',
                      style: AppTheme.headingStyle.copyWith(fontSize: 16, color: AppTheme.primaryCyan, letterSpacing: 1.5),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Component Breakdown
                if (widget.components.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No detailed telemetry available for this metric.', style: AppTheme.captionStyle),
                    ),
                  )
                else
                  ...widget.components.entries.map((e) => _buildComponentRow(e.key, e.value)).toList(),
                
                const SizedBox(height: 32),
                
                // Detailed Interpretation
                _buildInterpretationCard(),
                
                const SizedBox(height: 40),
                
                // Security Note
                _buildSecurityNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScoreCard(String tacticalStatus, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: widget.scoreValue),
                duration: const Duration(seconds: 1),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: value / 100,
                          strokeWidth: 8,
                          backgroundColor: AppTheme.glassBorder,
                          color: color,
                        ),
                      ),
                      Text(
                        value.toStringAsFixed(0),
                        style: AppTheme.headingStyle.copyWith(fontSize: 48, color: color),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tacticalStatus,
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildConfidenceBadge(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: AppTheme.glassBorder),
          const SizedBox(height: 16),
          Text(
            'Metric captures real-time physiological response and historical baseline variance for ${widget.scoreName.toLowerCase()}.',
            style: AppTheme.captionStyle.copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    final confColor = _getConfidenceColor(widget.confidence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: confColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: confColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 12, color: confColor),
          const SizedBox(width: 6),
          Text(
            'DATA QUALITY: ${widget.confidence.toUpperCase()}',
            style: TextStyle(
              color: confColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentRow(String label, dynamic rawValue) {
    final value = (rawValue is num) ? rawValue.toDouble() : 0.0;
    final normalizedLabel = label.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '').join(' ');
    
    // Most components are 0-100, but some might be raw units
    final isPercentage = value >= 0 && value <= 100;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                normalizedLabel,
                style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w500, color: AppTheme.textWhite),
              ),
              Row(
                children: [
                  Text(
                    value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                    style: AppTheme.titleStyle.copyWith(fontSize: 16, color: AppTheme.primaryCyan),
                  ),
                  if (isPercentage)
                    Text('%', style: AppTheme.captionStyle.copyWith(fontSize: 12, color: AppTheme.primaryCyan.withOpacity(0.6))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isPercentage ? (value / 100).clamp(0, 1) : 0.5,
              minHeight: 4,
              backgroundColor: AppTheme.glassBorder.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryCyan.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(color: AppTheme.primaryBlue.withOpacity(0.05)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'TACTICAL INTERPRETATION',
                style: AppTheme.titleStyle.copyWith(fontSize: 14, color: AppTheme.primaryBlue, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getInterpretation(),
            style: AppTheme.bodyStyle.copyWith(fontSize: 14, height: 1.6, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppTheme.textGray),
          const SizedBox(height: 8),
          Text(
            'All telemetry is end-to-end encrypted and processed in a secure environment.',
            textAlign: TextAlign.center,
            style: AppTheme.captionStyle.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _getInterpretation() {
    if (widget.scoreName.contains('Sleep')) {
      if (widget.scoreValue >= 80) return 'Sleep quality is optimal. Neural recovery and physiological restoration markers are at peak engagement levels.';
      if (widget.scoreValue >= 60) return 'Sleep coverage is sufficient, but data suggests potential interruptions. Monitor consistency across 72-hour windows.';
      return 'Critical Sleep Deprivation. Cognitive processing speed and long-duration endurance will be significantly degraded.';
    }
    if (widget.scoreName.contains('Recovery')) {
      if (widget.scoreValue >= 80) return 'Physiological state indicates full operational recovery. Ready for high-intensity physical or cognitive maneuvers.';
      return 'Signs of physiological strain detected. Heart Rate Variability (HRV) indicates the nervous system is in a reactive state.';
    }
    if (widget.scoreName.contains('Fatigue')) {
      if (widget.scoreValue >= 80) return 'Systemic fatigue is low. High work capacity and sustained focus are expected for immediate operations.';
      return 'Accumulated strain detected. Recent activity load has exceeded recovery rates. Risk of overtraining or burnout is elevated.';
    }
    return 'This metric reflects the current delta between your historical baseline and recent 24-hour telemetry. Maintain consistent wear for higher data confidence.';
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return AppTheme.accentGreen;
    if (score >= 60) return AppTheme.accentOrange;
    return AppTheme.accentRed;
  }

  Color _getConfidenceColor(String conf) {
    if (conf == 'high') return AppTheme.accentGreen;
    if (conf == 'medium') return AppTheme.primaryBlue;
    return AppTheme.accentRed;
  }
}
