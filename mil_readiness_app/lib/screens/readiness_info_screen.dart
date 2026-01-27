import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Static information screen explaining how readiness is calculated
/// No logic, just user education
class ReadinessInfoScreen extends StatelessWidget {
  const ReadinessInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('HOW IT WORKS', style: AppTheme.titleStyle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Readiness Score
            _buildInfoSection(
              icon: Icons.speed,
              title: 'Readiness Score',
              description: 'Your daily readiness is calculated from recovery, sleep quality, '
                  'and fitness trends. A higher score means you\'re ready for intense training.',
              color: AppTheme.primaryCyan,
            ),
            
            const SizedBox(height: 20),
            
            // Data Sources
            _buildInfoSection(
              icon: Icons.favorite,
              title: 'What We Measure',
              description: 'We analyze your heart rate, heart rate variability (HRV), '
                  'sleep duration and quality, and training load to give you a complete picture.',
              color: AppTheme.accentGreen,
            ),
            
            const SizedBox(height: 20),
            
            // Categories
            _buildInfoSection(
              icon: Icons.traffic,
              title: 'Go / Caution / No-Go',
              description: '• GO (75+): You\'re recovered and ready for high intensity\n'
                  '• CAUTION (55-74): Moderate activity recommended\n'
                  '• NO-GO (<55): Rest and recovery advised',
              color: AppTheme.accentOrange,
            ),
            
            const SizedBox(height: 20),
            
            // Privacy
            _buildInfoSection(
              icon: Icons.lock,
              title: 'Your Privacy',
              description: 'All your raw health data stays on your device. '
                  'Only computed scores can be synced if you enable that feature. '
                  'Your data is encrypted at rest using military-grade encryption.',
              color: AppTheme.primaryBlue,
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      decoration: AppTheme.glassCard(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTheme.titleStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTheme.bodyStyle.copyWith(
              height: 1.5,
              color: AppTheme.textGray,
            ),
          ),
        ],
      ),
    );
  }
}
