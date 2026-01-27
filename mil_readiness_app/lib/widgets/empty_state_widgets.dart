import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Calm, professional empty state widgets
/// Non-alarming, helpful messaging for when data is not available
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppTheme.textGray.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: AppTheme.textWhite,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Specific empty states for common scenarios
class NoDataEmptyState extends StatelessWidget {
  final VoidCallback? onRefresh;
  
  const NoDataEmptyState({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.analytics_outlined,
      title: 'No Data Yet',
      message: 'We\'re collecting your baseline data. Check back soon for your readiness insights.',
      actionLabel: onRefresh != null ? 'Refresh' : null,
      onAction: onRefresh,
    );
  }
}

class NoActivitiesEmptyState extends StatelessWidget {
  final VoidCallback? onAddActivity;
  
  const NoActivitiesEmptyState({super.key, this.onAddActivity});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.fitness_center_outlined,
      title: 'No Activities Logged',
      message: 'Start logging your workouts and activities to improve readiness tracking.',
      actionLabel: onAddActivity != null ? 'Log Activity' : null,
      onAction: onAddActivity,
    );
  }
}

class ConnectionNeededEmptyState extends StatelessWidget {
  final VoidCallback? onConnect;
  
  const ConnectionNeededEmptyState({super.key, this.onConnect});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.link_off,
      title: 'Health Data Not Connected',
      message: 'Connect your health data source to start tracking your readiness.',
      actionLabel: onConnect != null ? 'Connect Now' : null,
      onAction: onConnect,
    );
  }
}

class NoHistoryEmptyState extends StatelessWidget {
  const NoHistoryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.history,
      title: 'No History Available',
      message: 'Your readiness history will appear here as data is collected over time.',
    );
  }
}
