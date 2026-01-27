import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/security_config.dart';
import 'dart:math';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Rotation state machine states
enum RotationState {
  idle,
  keyGenerated,
  oldKeyArchived,
  rekeyInProgress,
  rekeyComplete,
  verified,
  failed,
}

/// Service for managing SQLCipher encryption key rotation
/// 
/// Implements a REAL key rotation using native PRAGMA rekey:
/// 1. Generate new key
/// 2. Archive old key (for recovery)
/// 3. Call native PRAGMA rekey
/// 4. Verify new key works
/// 5. Commit metadata only after verification
/// 
/// SECURITY: No export/import - keys should never leave the device
class KeyRotationService {
  // Singleton pattern
  KeyRotationService._();
  static final KeyRotationService instance = KeyRotationService._();
  
  static const _secureStorage = FlutterSecureStorage();
  static const _channel = MethodChannel('mil_readiness_app/sqlcipher');
  
  // Storage keys
  static const String _keyRotationDate = 'db_key_last_rotation';
  static const String _keyVersion = 'db_encryption_key_version';
  static const String _keyOldKeys = 'db_encryption_old_keys'; // JSON array
  static const String _keyRotationState = 'db_rotation_state';
  static const String _keyPendingNewKey = 'db_pending_new_key'; // Temporary during rotation
  
  // Current rotation state
  RotationState _currentState = RotationState.idle;
  
  /// Check if encryption key should be rotated
  Future<bool> shouldRotateKey() async {
    // Check if auto-rotation is enabled
    if (!SecurityConfigExtensions.shouldAutoRotateKeys()) {
      return false;
    }
    
    // Get last rotation date
    final lastRotationStr = await _secureStorage.read(key: _keyRotationDate);
    if (lastRotationStr == null) {
      // Never rotated - set current time as baseline
      await _saveRotationDate(DateTime.now());
      return false;
    }
    
    final lastRotation = DateTime.parse(lastRotationStr);
    final now = DateTime.now();
    final age = now.difference(lastRotation);
    
    // Check if key is older than rotation interval
    return age > SecurityConfig.keyRotationInterval;
  }
  
  /// Get key age in days
  Future<int> getKeyAge() async {
    final lastRotationStr = await _secureStorage.read(key: _keyRotationDate);
    if (lastRotationStr == null) {
      return 0;
    }
    
    final lastRotation = DateTime.parse(lastRotationStr);
    final now = DateTime.now();
    return now.difference(lastRotation).inDays;
  }
  
  /// Get days until next rotation
  Future<int> getDaysUntilRotation() async {
    final age = await getKeyAge();
    final interval = SecurityConfig.keyRotationInterval.inDays;
    final remaining = interval - age;
    return remaining > 0 ? remaining : 0;
  }
  
  /// Perform key rotation using native PRAGMA rekey
  /// 
  /// State machine ensures we never have an inconsistent state:
  /// - New key is only committed after verification
  /// - If rekey fails, we can rollback
  Future<bool> performRotation() async {
    if (!SecurityConfig.isProduction) {
      print('🔄 Starting encryption key rotation...');
    }
    
    // Check for incomplete previous rotation
    await _recoverFromIncompleteRotation();
    
    try {
      // Get current key version and key
      final currentVersion = await _getCurrentVersion();
      final newVersion = currentVersion + 1;
      final currentKey = await _getCurrentKey();
      
      if (currentKey == null) {
        throw Exception('No current encryption key found');
      }
      
      if (!SecurityConfig.isProduction) {
        print('   Current version: $currentVersion');
        print('   New version: $newVersion');
      }
      
      // STATE: Generate new key
      final newKey = _generateSecureKey();
      await _secureStorage.write(key: _keyPendingNewKey, value: newKey);
      await _setRotationState(RotationState.keyGenerated);
      
      // STATE: Archive old key
      await _archiveCurrentKey();
      await _setRotationState(RotationState.oldKeyArchived);
      
      // Get database path
      final dbPath = await _getDatabasePath();
      if (dbPath == null) {
        throw Exception('Cannot find database path');
      }
      
      // STATE: Rekey in progress - call native PRAGMA rekey
      await _setRotationState(RotationState.rekeyInProgress);
      
      final rekeyResult = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'rekeyDatabase',
        {
          'dbPath': dbPath,
          'oldKey': currentKey,
          'newKey': newKey,
        },
      );
      
      if (rekeyResult?['success'] != true) {
        throw Exception('PRAGMA rekey failed: ${rekeyResult?['message']}');
      }
      
      await _setRotationState(RotationState.rekeyComplete);
      
      // STATE: Verify new key works
      final verifyResult = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'verifyKey',
        {
          'dbPath': dbPath,
          'key': newKey,
        },
      );
      
      if (verifyResult?['valid'] != true) {
        throw Exception('Verification failed: ${verifyResult?['error']}');
      }
      
      // Run integrity check
      final integrityResult = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'integrityCheck',
        {
          'dbPath': dbPath,
          'key': newKey,
        },
      );
      
      if (integrityResult?['ok'] != true) {
        throw Exception('Integrity check failed: ${integrityResult?['result']}');
      }
      
      await _setRotationState(RotationState.verified);
      
      // COMMIT: Only now save the new key as current
      await _secureStorage.write(
        key: 'db_encryption_key_v$newVersion',
        value: newKey,
      );
      
      await _secureStorage.write(
        key: _keyVersion,
        value: newVersion.toString(),
      );
      
      await _saveRotationDate(DateTime.now());
      
      // Cleanup
      await _secureStorage.delete(key: _keyPendingNewKey);
      await _setRotationState(RotationState.idle);
      
      if (!SecurityConfig.isProduction) {
        print('✅ Key rotation completed successfully');
        print('   New version: $newVersion');
      }
      
      return true;
    } catch (e) {
      await _setRotationState(RotationState.failed);
      
      if (!SecurityConfig.isProduction) {
        print('❌ Key rotation failed: $e');
      }
      
      // Attempt rollback
      await _rollbackRotation();
      
      return false;
    }
  }
  
  /// Rollback an incomplete or failed rotation
  Future<void> _rollbackRotation() async {
    if (!SecurityConfig.isProduction) {
      print('🔙 Rolling back rotation...');
    }
    
    // Delete pending new key
    await _secureStorage.delete(key: _keyPendingNewKey);
    
    // Reset state
    await _setRotationState(RotationState.idle);
  }
  
  /// Recover from an incomplete rotation (app crashed mid-rotation)
  Future<void> _recoverFromIncompleteRotation() async {
    final stateStr = await _secureStorage.read(key: _keyRotationState);
    if (stateStr == null || stateStr == 'idle') {
      return;
    }
    
    if (!SecurityConfig.isProduction) {
      print('⚠️ Found incomplete rotation in state: $stateStr');
    }
    
    // If we crashed before rekey started, just cleanup
    if (stateStr == 'keyGenerated' || stateStr == 'oldKeyArchived') {
      await _rollbackRotation();
      return;
    }
    
    // If we crashed during or after rekey, we need to verify state
    if (stateStr == 'rekeyInProgress' || stateStr == 'rekeyComplete') {
      // Try to verify with both keys
      final pendingKey = await _secureStorage.read(key: _keyPendingNewKey);
      final currentKey = await _getCurrentKey();
      final dbPath = await _getDatabasePath();
      
      if (dbPath != null && pendingKey != null) {
        // Check if new key works
        final verifyNew = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'verifyKey',
          {'dbPath': dbPath, 'key': pendingKey},
        );
        
        if (verifyNew?['valid'] == true) {
          // New key works - commit the rotation
          final currentVersion = await _getCurrentVersion();
          final newVersion = currentVersion + 1;
          
          await _secureStorage.write(
            key: 'db_encryption_key_v$newVersion',
            value: pendingKey,
          );
          await _secureStorage.write(key: _keyVersion, value: newVersion.toString());
          await _saveRotationDate(DateTime.now());
          await _secureStorage.delete(key: _keyPendingNewKey);
          await _setRotationState(RotationState.idle);
          
          if (!SecurityConfig.isProduction) {
            print('✅ Recovered: committed pending rotation');
          }
          return;
        }
        
        // Check if old key still works
        if (currentKey != null) {
          final verifyOld = await _channel.invokeMethod<Map<dynamic, dynamic>>(
            'verifyKey',
            {'dbPath': dbPath, 'key': currentKey},
          );
          
          if (verifyOld?['valid'] == true) {
            // Old key still works - rollback
            await _rollbackRotation();
            if (!SecurityConfig.isProduction) {
              print('✅ Recovered: rolled back to old key');
            }
            return;
          }
        }
      }
      
      // Cannot recover - database may be corrupted
      if (!SecurityConfig.isProduction) {
        print('❌ CRITICAL: Cannot recover from incomplete rotation');
      }
    }
  }
  
  /// Get database path
  Future<String?> _getDatabasePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/mil_readiness_secure.db');
      if (await dbFile.exists()) {
        return dbFile.path;
      }
      // Try alternative path
      final altDbFile = File('${dir.path}/databases/mil_readiness_secure.db');
      if (await altDbFile.exists()) {
        return altDbFile.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get current encryption key
  Future<String?> _getCurrentKey() async {
    final version = await _getCurrentVersion();
    return await _secureStorage.read(key: 'db_encryption_key_v$version');
  }
  
  /// Generate cryptographically secure 256-bit encryption key
  String _generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
  
  /// Archive current encryption key for recovery
  Future<void> _archiveCurrentKey() async {
    final currentVersion = await _getCurrentVersion();
    final currentKey = await _secureStorage.read(
      key: 'db_encryption_key_v$currentVersion',
    );
    
    if (currentKey == null) return;
    
    // Get existing archived keys
    final oldKeysStr = await _secureStorage.read(key: _keyOldKeys);
    List<Map<String, String>> oldKeys = [];
    
    if (oldKeysStr != null) {
      try {
        final decoded = json.decode(oldKeysStr) as List<dynamic>;
        oldKeys = decoded.map((k) => Map<String, String>.from(k as Map)).toList();
      } catch (e) {
        // Ignore parse errors
      }
    }
    
    // Add current key to archive
    oldKeys.add({
      'version': currentVersion.toString(),
      'key': currentKey,
      'archived_at': DateTime.now().toIso8601String(),
    });
    
    // Keep only the last N keys
    if (oldKeys.length > SecurityConfig.maxOldKeysRetained) {
      oldKeys = oldKeys.sublist(oldKeys.length - SecurityConfig.maxOldKeysRetained);
    }
    
    // Save updated archive
    await _secureStorage.write(
      key: _keyOldKeys,
      value: json.encode(oldKeys),
    );
  }
  
  /// Get current key version
  Future<int> _getCurrentVersion() async {
    final versionStr = await _secureStorage.read(key: _keyVersion);
    return int.tryParse(versionStr ?? '1') ?? 1;
  }
  
  /// Save rotation date
  Future<void> _saveRotationDate(DateTime date) async {
    await _secureStorage.write(
      key: _keyRotationDate,
      value: date.toIso8601String(),
    );
  }
  
  /// Set rotation state (for state machine)
  Future<void> _setRotationState(RotationState state) async {
    _currentState = state;
    await _secureStorage.write(
      key: _keyRotationState,
      value: state.name,
    );
  }
  
  /// Get last rotation date
  Future<DateTime?> getLastRotationDate() async {
    final dateStr = await _secureStorage.read(key: _keyRotationDate);
    if (dateStr != null) {
      return DateTime.parse(dateStr);
    }
    return null;
  }
  
  /// Get rotation status summary
  Future<Map<String, dynamic>> getRotationStatus() async {
    final lastRotation = await getLastRotationDate();
    final age = await getKeyAge();
    final daysUntilRotation = await getDaysUntilRotation();
    final version = await _getCurrentVersion();
    
    return {
      'current_version': version,
      'last_rotation': lastRotation?.toIso8601String(),
      'age_days': age,
      'days_until_rotation': daysUntilRotation,
      'should_rotate': await shouldRotateKey(),
      'current_state': _currentState.name,
    };
  }
  
  // ============================================================================
  // EXPORT/IMPORT REMOVED FOR SECURITY
  // ============================================================================
  // 
  // Key export/import has been intentionally removed because:
  // 1. Encryption keys should NEVER leave the device
  // 2. User passwords for key derivation are typically too weak
  // 3. Military-grade apps should not allow key extraction
  // 4. If device is lost, data should be unrecoverable (by design)
  //
  // If backup is truly needed, implement server-side key escrow with
  // hardware security modules (HSM) and proper access controls.
  // ============================================================================
}
