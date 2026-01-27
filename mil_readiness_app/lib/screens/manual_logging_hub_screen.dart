import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/logging_dialogs.dart';
import '../services/session_controller.dart';

/// Manual Logging Hub - Central place for all manual data entry
/// Links to existing manual entry screens (sleep, activity)
class ManualLoggingHubScreen extends StatelessWidget {
  final SessionController session;
  
  const ManualLoggingHubScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final email = session.email ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MANUAL LOGGING'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkGradient
              : AppTheme.lightGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Quick Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildLogCard(
              context,
              icon: Icons.bedtime,
              title: 'Log Sleep',
              subtitle: 'Record manual sleep data',
              color: AppTheme.primaryCyan,
              onTap: () {
                final today = DateTime.now();
                final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                context.push('/manual-sleep-entry?email=$email&date=$dateStr');
              },
            ),
            
            const SizedBox(height: 12),
            
            _buildLogCard(
              context,
              icon: Icons.fitness_center,
              title: 'Log Activity',
              subtitle: 'Record workout or physical activity',
              color: AppTheme.accentOrange,
              onTap: () => context.push('/manual-activity-entry'),
            ),
            
            const SizedBox(height: 12),

            _buildLogCard(
              context,
              icon: Icons.water_drop_outlined,
              title: 'Log Hydration',
              subtitle: 'Record daily water intake',
              color: AppTheme.primaryCyan,
              onTap: () => LoggingDialogs.showHydrationDialog(context, email),
            ),
            
            const SizedBox(height: 12),

            _buildLogCard(
              context,
              icon: Icons.restaurant_outlined,
              title: 'Log Nutrition',
              subtitle: 'Assess nutrition quality',
              color: AppTheme.accentGreen,
              onTap: () => LoggingDialogs.showNutritionDialog(context, email),
            ),
            
            const SizedBox(height: 12),

            _buildLogCard(
              context,
              icon: Icons.psychology_outlined,
              title: 'Log Stress',
              subtitle: 'Record perceived stress level',
              color: AppTheme.accentOrange,
              onTap: () => LoggingDialogs.showStressDialog(context, email),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Recent Logs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppTheme.textWhite,
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.glassBorder.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text(
                  'Manual log history will appear here',
                  style: TextStyle(
                    color: AppTheme.textGray,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLogCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.glassBorder.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
