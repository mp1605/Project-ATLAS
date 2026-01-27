import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/comprehensive_readiness_result.dart';
import 'local_secure_store.dart';
import 'device_auth_service.dart';

/// Service to sync calculated readiness scores to dashboard
/// 
/// PRIVACY GUARANTEE: Sends ONLY aggregated scores, NEVER raw HealthKit data
class DashboardSyncService {
  final String baseUrl;
  final http.Client client;
  
  DashboardSyncService({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  String? _authToken;

  /// Ensure we have a valid auth token (Auto-Login)
  Future<void> _ensureAuth({String? userEmail}) async {
    if (_authToken == null) {
      print('🔄 DashboardSync: Token missing, attempting device auto-login...');
      _authToken = await DeviceAuthService.instance.authenticateDevice(userEmail: userEmail);
    }
  }
  
  /// Sync calculated scores to dashboard
  /// Returns true if successful, false otherwise
  Future<bool> syncScores({
    required String userEmail,
    required ComprehensiveReadinessResult scores,
  }) async {
    try {
      // 1. Ensure authentication
      await _ensureAuth(userEmail: userEmail);
      
      // 2. Get auth token
      final token = _authToken ?? await LocalSecureStore.instance.getJWTToken();
      
      if (token == null || token.isEmpty) {
        print('❌ DashboardSync: No auth token found');
        return false;
      }
      
      // Build payload with ONLY calculated scores
      final payload = _buildPayload(userEmail: userEmail, scores: scores);
      
      // Verify no raw HealthKit data leaked
      _validatePayload(payload);
      
      // Send to backend
      final targetUrl = '$baseUrl/api/v1/readiness';
      final response = await client.post(
        Uri.parse(targetUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ DashboardSync: Successfully synced scores for $userEmail');
        await _updateLastSyncTime(userEmail);
        return true;
      } else {
        print('❌ DashboardSync: Server error ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e, stack) {
      print('❌ DashboardSync: Error syncing scores: $e');
      print('   Stack trace: $stack');
      return false;
    }
  }
  
  /// Build API payload containing ONLY calculated/aggregated values
  Map<String, dynamic> _buildPayload({
    required String userEmail,
    required ComprehensiveReadinessResult scores,
  }) {
    return {
      'user_id': userEmail,
      'timestamp': scores.calculatedAt.toUtc().toIso8601String(),
      'overall_score': scores.overallReadiness, // REQUIRED by backend schema
      'scores': {
        // Using dashboard-friendly names (as per requirements)
        'readiness': scores.overallReadiness,
        'fatigue_index': scores.fatigueIndex,
        'recovery': scores.recoveryScore,
        'sleep_quality': scores.sleepIndex,
        'sleep_debt': scores.sleepDebt,
        'autonomic_balance': scores.cardioRespStability,
        'hrv_deviation': _extractHRVDeviation(scores),
        'resting_hr_deviation': _extractHRDeviation(scores),
        'respiratory_stability': _extractRespiratoryStability(scores),
        'oxygen_stability': _extractOxygenStability(scores),
        'training_load': scores.trainingReadiness,
        'acute_chronic_ratio': _extractACWR(scores),
        'cardiovascular_strain': scores.cardiovascularFitness,
        'stress_load': scores.stressLoad,
        'illness_risk': scores.illnessRisk,
        'overtraining_risk': scores.injuryRisk,
        'energy_availability': scores.workCapacity,
        'physical_status': scores.dailyActivity,
        'sleep_hours': _extractSleepHours(scores),
      },
      'category': scores.category,
      'confidence': scores.overallConfidence,
      'metadata': {
        'data_completeness': _calculateCompleteness(scores),
        'confidence_by_score': scores.confidenceLevels,
      }
    };
  }
  
  /// Extract HRV deviation from component breakdown
  double _extractHRVDeviation(ComprehensiveReadinessResult scores) {
    final breakdown = scores.componentBreakdown['Cardio-Resp Stability'];
    if (breakdown != null && breakdown.containsKey('hrv_deviation')) {
      return breakdown['hrv_deviation'] as double;
    }
    // Fallback: derive from cardio-resp stability
    return 100.0 - scores.cardioRespStability;
  }
  
  /// Extract HR deviation from component breakdown
  double _extractHRDeviation(ComprehensiveReadinessResult scores) {
    final breakdown = scores.componentBreakdown['Cardio-Resp Stability'];
    if (breakdown != null && breakdown.containsKey('hr_deviation')) {
      return breakdown['hr_deviation'] as double;
    }
    // Fallback
    return 100.0 - scores.cardioRespStability;
  }
  
  /// Extract respiratory stability from component breakdown
  double _extractRespiratoryStability(ComprehensiveReadinessResult scores) {
    final breakdown = scores.componentBreakdown['Cardio-Resp Stability'];
    if (breakdown != null && breakdown.containsKey('respiratory_stability')) {
      return breakdown['respiratory_stability'] as double;
    }
    return scores.cardioRespStability;
  }
  
  /// Extract oxygen saturation stability from component breakdown
  double _extractOxygenStability(ComprehensiveReadinessResult scores) {
    final breakdown = scores.componentBreakdown['Cardio-Resp Stability'];
    if (breakdown != null && breakdown.containsKey('oxygen_stability')) {
      return breakdown['oxygen_stability'] as double;
    }
    return scores.cardioRespStability;
  }
  
  /// Extract Acute/Chronic Workload Ratio from component breakdown
  double _extractACWR(ComprehensiveReadinessResult scores) {
    final breakdown = scores.componentBreakdown['Fatigue Index'];
    if (breakdown != null && breakdown.containsKey('acwr')) {
      return breakdown['acwr'] as double;
    }
    // Fallback: reasonable default
    return 1.0;
  }

  /// Extract sleep hours from component breakdown
  double _extractSleepHours(ComprehensiveReadinessResult scores) {
    final breakdown = scores.componentBreakdown['Sleep Index'];
    if (breakdown != null && breakdown.containsKey('asleep_min')) {
      return (breakdown['asleep_min'] as double) / 60.0;
    }
    return 0.0;
  }
  
  /// Calculate data completeness percentage
  int _calculateCompleteness(ComprehensiveReadinessResult scores) {
    int availableScores = 0;
    final allScores = scores.getAllScores();
    
    for (final score in allScores.values) {
      if (score > 0) availableScores++;
    }
    
    return ((availableScores / allScores.length) * 100).round();
  }
  
  /// Validate payload does NOT contain raw HealthKit data
  /// Throws if raw data detected
  void _validatePayload(Map<String, dynamic> payload) {
    // List of forbidden raw data fields
    final forbiddenFields = [
      'heart_rate', 'heart_rate_samples', 'hrv_samples',
      'sleep_stages', 'sleep_timestamps', 'steps_per_minute',
      'ecg_data', 'raw_oxygen', 'raw_respiratory',
      'gps_coordinates', 'nutrition_logs',
    ];
    
    final payloadString = jsonEncode(payload).toLowerCase();
    
    for (final field in forbiddenFields) {
      if (payloadString.contains(field)) {
        throw Exception(
          'SECURITY VIOLATION: Raw HealthKit data detected in payload: $field'
        );
      }
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSyncTime(String userEmail) async {
    await LocalSecureStore.instance.setDashboardLastSyncFor(
      userEmail,
      DateTime.now(),
    );
  }
  
  /// Get last sync time
  Future<DateTime?> getLastSyncTime(String userEmail) async {
    return await LocalSecureStore.instance.getDashboardLastSyncFor(userEmail);
  }
  
  /// Sync with retry logic
  Future<bool> syncWithRetry({
    required String userEmail,
    required ComprehensiveReadinessResult scores,
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('📤 DashboardSync: Attempt $attempt/$maxRetries');
      
      final success = await syncScores(
        userEmail: userEmail,
        scores: scores,
      );
      
      if (success) return true;
      
      // Exponential backoff
      if (attempt < maxRetries) {
        final delay = Duration(seconds: attempt * 2);
        print('   ⏳ Retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);
      }
    }
    
    print('❌ DashboardSync: Failed after $maxRetries attempts');
    return false;
  }
}
