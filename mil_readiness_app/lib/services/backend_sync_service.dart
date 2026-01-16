import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/comprehensive_readiness_result.dart';
import 'local_secure_store.dart';

/// Service for syncing calculated readiness scores to backend dashboard
class BackendSyncService {
  // Simple localhost URL - change if needed
  static const String baseUrl = 'http://localhost:3000/api';
  
  String? _authToken;
  int? _soldierId;
  
  BackendSyncService({String? authToken, int? soldierId}) {
    _authToken = authToken;
    _soldierId = soldierId;
  }
  
  /// Initialize with stored auth token
  static Future<BackendSyncService> create() async {
    final token = await LocalSecureStore.instance.getJWTToken();
    final soldierId = await LocalSecureStore.instance.getSoldierId();
    
    return BackendSyncService(authToken: token, soldierId: soldierId);
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
      print('📡 Submitting readiness scores to backend...');
      print('   Soldier ID: $soldierId');
      print('   Date: ${_formatDate(date)}');
      print('   Overall Score: ${result.overallReadiness.toStringAsFixed(1)}');
      
      final payload = {
        'soldier_id': soldierId,
        'date': _formatDate(date),
        'scores': {
          'overall_readiness': result.overallReadiness,
          'recovery_score': result.recoveryScore,
          'fatigue_index': result.fatigueIndex,
          'endurance_capacity': result.enduranceCapacity,
          'sleep_index': result.sleepIndex,
          'cardiovascular_fitness': result.cardiovascularFitness,
          'stress_load': result.stressLoad,
          'injury_risk': result.injuryRisk,
          'cardio_resp_stability': result.cardioRespStability,
          'illness_risk': result.illnessRisk,
          'daily_activity': result.dailyActivity,
          'work_capacity': result.workCapacity,
          'altitude_score': result.altitudeScore,
          'cardiac_safety_penalty': result.cardiacSafetyPenalty,
          'sleep_debt': result.sleepDebt,
          'training_readiness': result.trainingReadiness,
          'cognitive_alertness': result.cognitiveAlertness,
          'thermoregulatory_adaptation': result.thermoregulatoryAdaptation,
        },
        'category': result.category,
        'confidence': result.overallConfidence,
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/readiness/submit'),
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
        body: json.encode(payload),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - server may be offline');
        },
      );
      
      if (response.statusCode == 201) {
        print('✅ Scores submitted successfully to backend');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ Authentication failed - token may be expired');
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
    required int soldierId,
    int? days,
  }) async {
    try {
      var url = '$baseUrl/readiness/soldier/$soldierId';
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
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/../health'),
      ).timeout(const Duration(seconds: 5));
      
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
