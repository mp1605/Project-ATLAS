import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/comprehensive_readiness_result.dart';
import 'local_secure_store.dart';
import 'device_auth_service.dart';


import '../config/app_config.dart';

/// Service for syncing calculated readiness scores to backend dashboard
class BackendSyncService {
  // Configured Base URL
  static const String baseUrl = '${AppConfig.apiBaseUrl}/api/v1';
  
  String? _authToken;
  int? _soldierId;
  String? _userEmail;
  
  BackendSyncService({String? authToken, int? soldierId, String? userEmail}) {
    _authToken = authToken;
    _soldierId = soldierId;
    _userEmail = userEmail;
  }
  
  /// Initialize with stored auth token
  static Future<BackendSyncService> create() async {
    final token = await LocalSecureStore.instance.getJWTToken();
    final soldierId = await LocalSecureStore.instance.getSoldierId();
    final email = await LocalSecureStore.instance.getActiveSessionEmail();
    
    return BackendSyncService(authToken: token, soldierId: soldierId, userEmail: email);
  }
  
  /// Ensure we have a valid auth token (Auto-Login)
  Future<void> _ensureAuth() async {
    if (_authToken == null) {
      print('🔄 BackendSync: Token missing, attempting device auto-login...');
      _authToken = await DeviceAuthService.instance.authenticateDevice(userEmail: _userEmail);
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _authToken != null;
  
  /// Get stored soldier ID
  int? get soldierId => _soldierId;


  /// Submit calculated readiness scores to backend
  /// Returns true if successful, false otherwise
  Future<bool> submitReadinessScores({
    required int soldierId,
    required DateTime date,
    required ComprehensiveReadinessResult result,
  }) async {
    try {
      await _ensureAuth(); // Auto-login if needed
      
      print('📡 Submitting readiness scores to backend...');
      print('   Soldier ID: $soldierId');
      print('   Date: ${_formatDate(date)}');
      print('   Overall Score: ${result.overallReadiness.toStringAsFixed(1)}');
      
      final payload = {
        'user_id': _userEmail ?? (_soldierId != null ? 'soldier_$_soldierId@example.com' : 'unknown@example.com'),
        'timestamp': date.toUtc().toIso8601String(),
        'overall_score': result.overallReadiness, // Added to match backend schema
        'scores': {
          // Backend expects these exact field names (from validation.ts)
          'readiness': result.overallReadiness,
          'fatigue_index': result.fatigueIndex,
          'recovery': result.recoveryScore,
          'sleep_quality': result.sleepIndex,
          'sleep_debt': result.sleepDebt,
          'autonomic_balance': result.cardioRespStability,
          'hrv_deviation': 100 - result.cardioRespStability, // Derived
          'resting_hr_deviation': 100 - result.cardioRespStability, // Derived
          'respiratory_stability': result.cardioRespStability,
          'oxygen_stability': result.cardioRespStability,
          'training_load': result.trainingReadiness,
          'acute_chronic_ratio': 1.0, // Default ACWR value
          'cardiovascular_strain': result.cardiovascularFitness,
          'stress_load': result.stressLoad,
          'illness_risk': result.illnessRisk,
          'overtraining_risk': result.injuryRisk,
          'energy_availability': result.workCapacity,
          'physical_status': result.dailyActivity,
        },
        'category': result.category,
        'confidence': result.overallConfidence,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/readiness'),
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
        body: json.encode(payload),
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw Exception('Request timeout - server may be offline');
        },
      );
      
      if (response.statusCode == 201) {
        print('✅ Scores submitted successfully to backend');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed - token may be expired');
        // Clear token to force re-auth next time
        _authToken = null; 
        await LocalSecureStore.instance.clearJWTToken();
        return false;
      } else {
        print('❌ Failed to submit scores: ${response.statusCode}');
        print('   Response: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error submitting scores: $e');
      if (e.toString().contains('SocketException') || 
          e.toString().contains('timeout')) {
        print('   Network error - server may be offline or unreachable');
      }
      print('   Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Get soldier's historical readiness scores
  Future<List<Map<String, dynamic>>> getHistoricalScores({
    required String userEmail,
    int? days,
  }) async {
    try {
      var url = '$baseUrl/readiness/$userEmail/history';
      if (days != null) {
        url += '?days=$days';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> historicalData = data['data'] ?? [];
        return historicalData.cast<Map<String, dynamic>>();
      } else {
        print('Failed to fetch historical scores: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching historical scores: $e');
      return [];
    }
  }
  
  /// Test connection to backend
  Future<bool> testConnection() async {
    final testUrl = '${AppConfig.apiBaseUrl}/health';
    try {
      print('📡 Testing connection to: $testUrl');
      final response = await http.get(
        Uri.parse(testUrl),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        print('✅ Backend connection successful');
        return true;
      } else {
        print('❌ Backend returned: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Cannot connect to backend: $e');
      print('   Make sure server is running on $baseUrl');
      return false;
    }
  }
  
  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// Convert text confidence to numeric (0.0-1.0)
  double _confidenceToNumeric(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return 0.9;
      case 'medium':
        return 0.7;
      case 'low':
        return 0.5;
      default:
        return 0.75;
    }
  }
}
