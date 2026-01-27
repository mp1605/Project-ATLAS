import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../models/comprehensive_readiness_result.dart';
import '../screens/component_detail_screen.dart';

/// Helper for component navigation and actions
class ComponentHelper {
  /// Show component detail screen for Sleep
  static void showSleepDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComponentDetailScreen(
          componentName: 'Sleep Quality',
          componentDescription: 'Sleep contributes 25% to your readiness score. Quality sleep supports recovery, cognitive function, and physical performance. Aim for 7-9 hours of consistent, uninterrupted sleep.',
          icon: Icons.bedtime,
          color: AppTheme.primaryCyan,
          scoreExtractor: (result) => result.sleepIndex,
        ),
      ),
    );
  }
  
  /// Show component detail screen for HRV (Recovery)
  static void showHRVDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComponentDetailScreen(
          componentName: 'Heart Rate Variability',
          componentDescription: 'HRV measures your autonomic nervous system balance. Higher HRV indicates better recovery and readiness for physical stress. This is a key indicator of readiness.',
          icon: Icons.favorite,
          color: const Color(0xFFFF6B9D),
          scoreExtractor: (result) => result.recoveryScore,
        ),
      ),
    );
  }
  
  /// Show component detail screen for Activity
  static void showActivityDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComponentDetailScreen(
          componentName: 'Daily Activity',
          componentDescription: 'Your movement and physical activity levels. Regular activity improves cardiovascular health, but overtraining can reduce readiness. Balance is key.',
          icon: Icons.directions_run,
          color: AppTheme.accentOrange,
          scoreExtractor: (result) => result.dailyActivity,
        ),
      ),
    );
  }
  
  /// Show contextual action sheet for a component
  static void showComponentActions(
    BuildContext context, {
    required String componentName,
    required VoidCallback onViewDetail,
    required VoidCallback onLogManual,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.bgDark
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  componentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textWhite,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildActionTile(
                context,
                icon: Icons.history,
                title: 'View 30-Day History',
                onTap: () {
                  Navigator.pop(context);
                  onViewDetail();
                },
              ),
              
              _buildActionTile(
                context,
                icon: Icons.edit,
                title: 'Log Manual Entry',
                onTap: () {
                  Navigator.pop(context);
                  onLogManual();
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  
  static Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryCyan),
      title: Text(
        title,
        style: const TextStyle(color: AppTheme.textWhite),
      ),
      onTap: onTap,
    );
  }
}
