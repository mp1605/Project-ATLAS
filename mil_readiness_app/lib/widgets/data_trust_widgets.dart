import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/data_trust_service.dart';
import '../theme/app_theme.dart';

/// Last Synced Freshness Indicator (lightweight, top-level)
/// Shows color-coded sync freshness with human-friendly time
class SyncFreshnessIndicator extends StatelessWidget {
  final DateTime? lastSyncTime;
  final bool compact;
  
  const SyncFreshnessIndicator({
    super.key,
    required this.lastSyncTime,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final freshness = DataTrustService.calculateSyncFreshness(lastSyncTime);
    final timeAgoText = DataTrustService.getTimeAgoText(lastSyncTime);
    
    Color indicatorColor;
    IconData icon;
    
    switch (freshness) {
      case SyncFreshness.recent:
        indicatorColor = AppTheme.accentGreen;
        icon = Icons.check_circle_outline;
        break;
      case SyncFreshness.stale:
        indicatorColor = AppTheme.accentOrange;
        icon = Icons.schedule;
        break;
      case SyncFreshness.unknown:
        indicatorColor = AppTheme.textGray;
        icon = Icons.help_outline;
        break;
    }
    
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: indicatorColor),
          const SizedBox(width: 4),
          Text(
            timeAgoText,
            style: TextStyle(
              color: indicatorColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: indicatorColor),
          const SizedBox(width: 6),
          Text(
            'Last synced: $timeAgoText',
            style: TextStyle(
              color: indicatorColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Connected Sources Card - platform-aware health connection status
class ConnectedSourcesCard extends StatelessWidget {
  final HealthConnectionStatus connectionStatus;
  final VoidCallback? onManageConnection;
  
  const ConnectedSourcesCard({
    super.key,
    required this.connectionStatus,
    this.onManageConnection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connectionStatus.isConnected 
                  ? Icons.cloud_done_outlined 
                  : Icons.cloud_off_outlined,
                color: connectionStatus.isConnected 
                  ? AppTheme.accentGreen 
                  : AppTheme.textGray,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Health Data Source',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connectionStatus.platform,
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBadge(),
                  ],
                ),
              ),
              if (onManageConnection != null)
                TextButton.icon(
                  onPressed: onManageConnection,
                  icon: const Icon(Icons.settings_outlined, size: 14),
                  label: const Text('Manage'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge() {
    Color badgeColor;
    String statusText;
    IconData statusIcon;
    
    if (connectionStatus.isConnected) {
      if (connectionStatus.hasLimitedAccess) {
        badgeColor = AppTheme.accentOrange;
        statusText = 'Limited access';
        statusIcon = Icons.warning_amber_outlined;
      } else {
        badgeColor = AppTheme.accentGreen;
        statusText = 'Connected ✓';
        statusIcon = Icons.check_circle_outline;
      }
    } else {
      badgeColor = AppTheme.textGray;
      statusText = 'Not connected';
      statusIcon = Icons.sync_disabled;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calm delayed-sync messaging banner (non-scary)
class CalmSyncMessageBanner extends StatelessWidget {
  final String message;
  final bool isWarning;
  
  const CalmSyncMessageBanner({
    super.key,
    required this.message,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppTheme.accentOrange : AppTheme.primaryCyan;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.info_outline : Icons.cloud_sync_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Offline mode indicator (subtle, non-blocking)
class OfflineModeIndicator extends StatelessWidget {
  const OfflineModeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.textGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.textGray.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 14,
            color: AppTheme.textGray,
          ),
          const SizedBox(width: 8),
          Text(
            DataTrustService.getOfflineModeMessage(),
            style: TextStyle(
              color: AppTheme.textGray,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
