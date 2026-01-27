import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/wearable_type.dart';
import '../services/local_secure_store.dart';
import '../adapters/health_adapter_factory.dart';
import '../adapters/apple_health_adapter.dart';

/// Service to provide data trust and sync visibility information
/// READ-ONLY - does not modify sync behavior or trigger any background tasks
class DataTrustService {
  DataTrustService._();
  
  /// Sync freshness states
  static const Duration _recentThreshold = Duration(hours: 4);
  static const Duration _staleThreshold = Duration(hours: 24);
  
  /// Calculate sync freshness from last calculation time
  /// Returns: 'recent' (green), 'stale' (orange), or 'unknown' (gray)
  static SyncFreshness calculateSyncFreshness(DateTime? lastCalcTime) {
    if (lastCalcTime == null) {
      return SyncFreshness.unknown;
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastCalcTime);
    
    if (difference < _recentThreshold) {
      return SyncFreshness.recent;
    } else if (difference < _staleThreshold) {
      return SyncFreshness.stale;
    } else {
      return SyncFreshness.unknown;
    }
  }
  
  /// Get human-friendly time ago text
  static String getTimeAgoText(DateTime? lastTime) {
    if (lastTime == null) {
      return 'Unknown';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hr' : 'hrs'} ago';
    } else {
      final days = difference.inDays;
      return '${days} ${days == 1 ? 'day' : 'days'} ago';
    }
  }
  
  /// Get health connection status for current platform
  static Future<HealthConnectionStatus> getHealthConnectionStatus(String userEmail) async {
    try {
      // Get selected wearable for user
      final selectedWearableStr = await LocalSecureStore.instance.getSelectedWearableFor(userEmail);
      
      if (selectedWearableStr == null) {
        return HealthConnectionStatus(
          platform: _getCurrentPlatform(),
          isConnected: false,
          hasLimitedAccess: false,
          wearableType: null,
        );
      }
      
      final wearableType = WearableType.values.firstWhere(
        (type) => type.name == selectedWearableStr,
        orElse: () => WearableType.other,
      );
      
      // Check if selected wearable is implemented
      final isImplemented = HealthAdapterFactory.isImplemented(wearableType);
      
      if (!isImplemented) {
        return HealthConnectionStatus(
          platform: _getCurrentPlatform(),
          isConnected: false,
          hasLimitedAccess: false,
          wearableType: wearableType,
        );
      }
      
      // For Apple Watch, check permissions (simplified - actual permission check would require adapter call)
      if (wearableType == WearableType.appleWatch && Platform.isIOS) {
        // Assume connected if selected (permission check would require async health plugin call)
        return HealthConnectionStatus(
          platform: 'Apple Health',
          isConnected: true,
          hasLimitedAccess: false,
          wearableType: wearableType,
        );
      }
      
      return HealthConnectionStatus(
        platform: _getCurrentPlatform(),
        isConnected: false,
        hasLimitedAccess: false,
        wearableType: wearableType,
      );
    } catch (e) {
      print('Error getting health connection status: $e');
      return HealthConnectionStatus(
        platform: _getCurrentPlatform(),
        isConnected: false,
        hasLimitedAccess: false,
        wearableType: null,
      );
    }
  }
  
  /// Get current platform display name
  static String _getCurrentPlatform() {
    if (Platform.isIOS) {
      return 'Apple Health';
    } else if (Platform.isAndroid) {
      return 'Health Connect';
    } else {
      return 'Unknown Platform';
    }
  }
  
  /// Check if device is offline (no network connectivity)
  /// Note: Returns false for now - proper network check would require connectivity_plus package
  static Future<bool> isOffline() async {
    // Placeholder - would require connectivity_plus package for real implementation
    // For now, assume online to avoid false positives
    return false;
  }
  
  /// Get calm message for delayed sync
  static String getCalmDelayedMessage(SyncFreshness freshness, bool isConnected) {
    if (!isConnected) {
      return 'Reconnect to keep readiness up to date.';
    }
    
    if (freshness == SyncFreshness.stale || freshness == SyncFreshness.unknown) {
      return 'Health data may be delayed. We\'ll retry automatically.';
    }
    
    return '';
  }
  
  /// Get offline mode message
  static String getOfflineModeMessage() {
    return 'Offline mode: showing last available data.';
  }
}

/// Sync freshness enumeration
enum SyncFreshness {
  recent,  // Green: 0-4 hours
  stale,   // Orange: 4-24 hours
  unknown, // Gray: >24 hours or null
}

/// Health connection status data class
class HealthConnectionStatus {
  final String platform;
  final bool isConnected;
  final bool hasLimitedAccess;
  final WearableType? wearableType;
  
  HealthConnectionStatus({
    required this.platform,
    required this.isConnected,
    required this.hasLimitedAccess,
    required this.wearableType,
  });
}
