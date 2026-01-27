import '../services/local_secure_store.dart';

class AppConfig {
  // Default base URL (production). Can be overridden by LocalSecureStore.
  static String apiBaseUrl = 'https://atlas-backend-dx6g.onrender.com';

  /// Load custom URL from secure storage if present
  static Future<void> loadFromStore() async {
    final customUrl = await LocalSecureStore.instance.getApiBaseUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      apiBaseUrl = customUrl;
      print('🔧 AppConfig: Loaded custom API URL: $apiBaseUrl');
    }
  }

  /// Update URL and save to store
  static Future<void> setApiUrl(String newUrl) async {
    // Basic validation
    if (!newUrl.startsWith('http')) {
      newUrl = 'https://$newUrl';
    }
    // Strip trailing slash
    if (newUrl.endsWith('/')) {
      newUrl = newUrl.substring(0, newUrl.length - 1);
    }

    apiBaseUrl = newUrl;
    await LocalSecureStore.instance.setApiBaseUrl(newUrl);
    print('🔧 AppConfig: Updated API URL to: $apiBaseUrl');
  }
}
