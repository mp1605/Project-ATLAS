import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart'; 
import '../config/app_config.dart';
import 'local_secure_store.dart';

/// Service to handle Device Authentication ("Phase 4 Auth")
/// 
/// Responsibilities:
/// 1. Get or create a unique Device ID
/// 2. Authenticate with Backend via /auth/device-login
/// 3. Store and refresh the JWT token
class DeviceAuthService {
  // Singleton
  DeviceAuthService._();
  static final DeviceAuthService instance = DeviceAuthService._();
  
  static const String _kDeviceIdKey = 'device_auth_id';
  
  /// Authenticate the device and ensure we have a valid JWT
  /// Returns the access token if successful, null otherwise
  Future<String?> authenticateDevice({String? userEmail}) async {
    try {
      // 1. Get Device ID
      String? deviceId = await LocalSecureStore.instance.read(key: _kDeviceIdKey); // We need to add raw read/write to SecureStore or add specific getter
      
      if (deviceId == null) {
        // Generate new persistent ID
        deviceId = const Uuid().v4();
        // Store it (we need to access securely)
        // For now, assuming LocalSecureStore has a generic write or we add specific method
        // Using a temporary workaround if generic read/write isn't exposed:
        // Ideally: await LocalSecureStore.instance.setDeviceId(deviceId);
        await _storeDeviceId(deviceId); 
      }
      
      print('🔐 DeviceAuth: Authenticating device $deviceId...');
      
      // Get User Name from Secure Store if available
      String? fullName;
      if (userEmail != null) {
        final userProfile = await LocalSecureStore.instance.getRegisteredUser(userEmail);
        fullName = userProfile?.fullName;
      }
      
      print('👤 DeviceAuth: Linking to user: $userEmail ($fullName)');
      
      // 2. Call Backend
      final url = '${AppConfig.apiBaseUrl}/api/v1/auth/device-login';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'email': userEmail, // Optional, links device to user if provided
          'full_name': fullName, // Send name to backend
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        
        // 3. Store Token
        await LocalSecureStore.instance.setJWTToken(token);
        print('✅ DeviceAuth: Authentication successful. Token stored.');
        return token;
      } else {
        print('❌ DeviceAuth: Auth failed ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ DeviceAuth: Error: $e');
      return null;
    }
  }
  
  // Helper to store device ID using the store instance
  Future<void> _storeDeviceId(String id) async {
     await LocalSecureStore.instance.write(key: _kDeviceIdKey, value: id);
     print('📱 DeviceAuth: Device ID $id persisted.');
  }
}
