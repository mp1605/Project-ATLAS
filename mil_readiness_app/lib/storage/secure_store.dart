import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> writeBool(String key, bool value) async {
    await _storage.write(key: key, value: value.toString()); // "true"/"false"
  }

  Future<bool?> readBool(String key) async {
    final v = await _storage.read(key: key);
    if (v == null) return null;
    return v.toLowerCase() == 'true';
  }

  Future<void> writeString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readString(String key) async {
    return _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
