import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';

class LocalSecureStore {
  LocalSecureStore._();
  static final LocalSecureStore instance = LocalSecureStore._();

  static const FlutterSecureStorage _ss = FlutterSecureStorage();

  // Keys (base)
  static const String _kHealthAuthorized = 'health_authorized';
  static const String _kHealthAuthCheckedAt = 'health_auth_checked_at';
  static const String _kHealthLastSyncAt = 'health_last_sync_at';
  static const String _kHealthLastSyncStatus = 'health_last_sync_status'; // "ok", "no_permission", "error"

  static const String _kActiveSessionEmail = "session.active.email";
  static const String _kRawShareConsent = "consent.raw.share"; // "1" or "0"
  static const String _kAuthorizeCompleted = "authorize.completed"; // "1" or "0"

  static String _userKey(String email) => "user.profile.${email.toLowerCase()}";
  static String _scoped(String email, String key) => "$key.${email.toLowerCase()}";

  // Generic read/write for internal services (like DeviceAuth)
  Future<String?> read({required String key}) => _ss.read(key: key);
  Future<void> write({required String key, required String value}) => _ss.write(key: key, value: value);

  // ---------- Helpers ----------
  String _randomSalt({int length = 16}) {
    const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
    }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode("$salt::$password");
    return sha256.convert(bytes).toString();
  }

  // ---------- User ----------
  Future<void> registerUser(UserProfile profile, String password) async {
    final salt = _randomSalt();
    final hash = _hashPassword(password, salt);

    final secured = profile.copyWith(
      passwordSalt: salt,
      passwordHash: hash,
    );

    await _ss.write(key: _userKey(profile.email), value: jsonEncode(secured.toJson()));
  }

  Future<UserProfile?> getRegisteredUser(String email) async {
    final raw = await _ss.read(key: _userKey(email));
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final user = await getRegisteredUser(normalized);
    if (user == null) return false;

    final computed = _hashPassword(password, user.passwordSalt);
    final ok = computed == user.passwordHash;

    if (ok) {
      await _ss.write(key: _kActiveSessionEmail, value: normalized);
    }
    return ok;
  }

  Future<String?> getActiveSessionEmail() async {
    return _ss.read(key: _kActiveSessionEmail);
  }

  Future<void> clearSession() async {
    await _ss.delete(key: _kActiveSessionEmail);
  }

  // ---------- Consent: Raw data share (PER USER) ----------
  Future<void> setRawDataShareConsentFor(String email, bool allow) async {
    await _ss.write(key: _scoped(email, _kRawShareConsent), value: allow ? "1" : "0");
  }

  /// null = not decided yet
  Future<bool?> getRawDataShareConsentFor(String email) async {
    final v = await _ss.read(key: _scoped(email, _kRawShareConsent));
    if (v == null || v.isEmpty) return null;
    return v == "1";
  }

  Future<void> clearRawDataShareConsentFor(String email) async {
    await _ss.delete(key: _scoped(email, _kRawShareConsent));
  }

  // ---------- Apple Health authorization flags (PER USER onboarding flags) ----------
  Future<void> setHealthAuthorizedFor(String email, bool value) async {
    await _ss.write(key: _scoped(email, _kHealthAuthorized), value: value.toString());
  }

  Future<bool> getHealthAuthorizedFor(String email) async {
    final v = await _ss.read(key: _scoped(email, _kHealthAuthorized));
    return (v ?? 'false').toLowerCase() == 'true';
  }

  Future<void> setHealthAuthCheckedAtFor(String email, DateTime dt) async {
    await _ss.write(key: _scoped(email, _kHealthAuthCheckedAt), value: dt.toIso8601String());
  }

  Future<DateTime?> getHealthAuthCheckedAtFor(String email) async {
    final v = await _ss.read(key: _scoped(email, _kHealthAuthCheckedAt));
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  Future<void> clearHealthAuthStatusFor(String email) async {
    await _ss.delete(key: _scoped(email, _kHealthAuthorized));
    await _ss.delete(key: _scoped(email, _kHealthAuthCheckedAt));
  }

  // ---------- Authorize step complete (PER USER) ----------
  Future<void> setAuthorizeCompletedFor(String email, bool done) async {
    await _ss.write(key: _scoped(email, _kAuthorizeCompleted), value: done ? "1" : "0");
  }

  Future<bool> getAuthorizeCompletedFor(String email) async {
    final v = await _ss.read(key: _scoped(email, _kAuthorizeCompleted));
    return v == "1";
  }

  Future<void> clearAuthorizeCompletedFor(String email) async {
    await _ss.delete(key: _scoped(email, _kAuthorizeCompleted));
  }

  // ---------- Live Sync state (PER USER) ----------
  Future<void> setHealthLastSyncAtFor(String email, DateTime dt) async {
    await _ss.write(key: _scoped(email, _kHealthLastSyncAt), value: dt.toIso8601String());
  }

  Future<DateTime?> getHealthLastSyncAtFor(String email) async {
    final v = await _ss.read(key: _scoped(email, _kHealthLastSyncAt));
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  Future<void> setHealthLastSyncStatusFor(String email, String status) async {
    await _ss.write(key: _scoped(email, _kHealthLastSyncStatus), value: status);
  }

  Future<String?> getHealthLastSyncStatusFor(String email) async {
    return _ss.read(key: _scoped(email, _kHealthLastSyncStatus));
  }

  // ---------- Wearable Selection ----------
  static const String _kSelectedWearable = 'selected_wearable';

  /// Get the user's selected wearable device type
  /// Returns null if no device has been selected yet
  Future<String?> getSelectedWearableFor(String email) async {
    return _ss.read(key: _scoped(email, _kSelectedWearable));
  }

  /// Set the user's selected wearable device type
  /// Stores the wearable type name (e.g., 'appleWatch', 'garmin')
  Future<void> setSelectedWearableFor(String email, String wearableTypeName) async {
    await _ss.write(key: _scoped(email, _kSelectedWearable), value: wearableTypeName);
  }

  /// Clear the user's selected wearable (for device switching)
  Future<void> clearSelectedWearableFor(String email) async {
    await _ss.delete(key: _scoped(email, _kSelectedWearable));
  }

  // ---------- Backend Sync (JWT Token) ----------
  static const String _kJWTToken = 'backend_jwt_token';
  static const String _kSoldierId = 'backend_soldier_id';

  /// Store JWT token for backend API authentication
  Future<void> setJWTToken(String token) async {
    await _ss.write(key: _kJWTToken, value: token);
    print('✅ JWT token stored securely');
  }

  /// Get stored JWT token
  Future<String?> getJWTToken() async {
    return _ss.read(key: _kJWTToken);
  }

  /// Clear JWT token (logout from backend)
  Future<void> clearJWTToken() async {
    await _ss.delete(key: _kJWTToken);
  }

  /// Store soldier ID for backend sync
  Future<void> setSoldierId(int id) async {
    await _ss.write(key: _kSoldierId, value: id.toString());
  }

  /// Get soldier ID
  Future<int?> getSoldierId() async {
    final value = await _ss.read(key: _kSoldierId);
    return value != null ? int.tryParse(value) : null;
  }

  // ===== DASHBOARD SYNC METHODS =====
  
  /// Store authentication token for dashboard API
  Future<void> setAuthToken(String token) async {
    await _ss.write(key: 'auth_token', value: token);
  }
  
  /// Get authentication token for dashboard API
  Future<String?> getAuthToken() async {
    return await _ss.read(key: 'auth_token');
  }
  
  /// Store last dashboard sync timestamp for a user
  Future<void> setDashboardLastSyncFor(String email, DateTime timestamp) async {
    await _ss.write(
      key: 'dashboard_last_sync_$email',
      value: timestamp.toIso8601String(),
    );
  }
  
  /// Get last dashboard sync timestamp for a user
  Future<DateTime?> getDashboardLastSyncFor(String email) async {
    final value = await _ss.read(key: 'dashboard_last_sync_$email');
    return value != null ? DateTime.tryParse(value) : null;
  }

  /// ⚠️ DANGER: Clear ALL stored data (for testing/reset)
  /// This will delete all users, sessions, and settings
  Future<void> clearAllData() async {
    await _ss.deleteAll();
    print('🗑️ All secure storage data cleared');
  }
}
