import Foundation
import Flutter

/// Native iOS plugin for SQLCipher key rotation
/// 
/// Provides PRAGMA rekey functionality that cannot be done in pure Dart.
/// Uses the existing SQLCipher database from sqflite_sqlcipher.
class SqlCipherPlugin: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "mil_readiness_app/sqlcipher",
            binaryMessenger: registrar.messenger()
        )
        let instance = SqlCipherPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "rekeyDatabase":
            guard let args = call.arguments as? [String: Any],
                  let dbPath = args["dbPath"] as? String,
                  let oldKey = args["oldKey"] as? String,
                  let newKey = args["newKey"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", 
                                   message: "Missing dbPath, oldKey, or newKey", 
                                   details: nil))
                return
            }
            rekeyDatabase(dbPath: dbPath, oldKey: oldKey, newKey: newKey, result: result)
            
        case "verifyKey":
            guard let args = call.arguments as? [String: Any],
                  let dbPath = args["dbPath"] as? String,
                  let key = args["key"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", 
                                   message: "Missing dbPath or key", 
                                   details: nil))
                return
            }
            verifyKey(dbPath: dbPath, key: key, result: result)
            
        case "integrityCheck":
            guard let args = call.arguments as? [String: Any],
                  let dbPath = args["dbPath"] as? String,
                  let key = args["key"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", 
                                   message: "Missing dbPath or key", 
                                   details: nil))
                return
            }
            integrityCheck(dbPath: dbPath, key: key, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Rekey database using PRAGMA rekey
    /// 
    /// Steps:
    /// 1. Open database with old key
    /// 2. Execute PRAGMA rekey = 'new_key'
    /// 3. Close database
    /// 4. Return success/failure
    private func rekeyDatabase(dbPath: String, oldKey: String, newKey: String, result: @escaping FlutterResult) {
        var db: OpaquePointer?
        
        // Open database with old key
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            result(FlutterError(code: "OPEN_FAILED", 
                               message: "Failed to open database", 
                               details: String(cString: sqlite3_errmsg(db))))
            sqlite3_close(db)
            return
        }
        
        // Set the old key
        let keyQuery = "PRAGMA key = '\(oldKey.replacingOccurrences(of: "'", with: "''"))';"
        if sqlite3_exec(db, keyQuery, nil, nil, nil) != SQLITE_OK {
            result(FlutterError(code: "KEY_FAILED", 
                               message: "Failed to set encryption key", 
                               details: String(cString: sqlite3_errmsg(db))))
            sqlite3_close(db)
            return
        }
        
        // Verify we can read the database (ensures old key is correct)
        if sqlite3_exec(db, "SELECT count(*) FROM sqlite_master;", nil, nil, nil) != SQLITE_OK {
            result(FlutterError(code: "KEY_INVALID", 
                               message: "Old key is invalid - cannot read database", 
                               details: String(cString: sqlite3_errmsg(db))))
            sqlite3_close(db)
            return
        }
        
        // Execute PRAGMA rekey with new key
        let rekeyQuery = "PRAGMA rekey = '\(newKey.replacingOccurrences(of: "'", with: "''"))';"
        if sqlite3_exec(db, rekeyQuery, nil, nil, nil) != SQLITE_OK {
            result(FlutterError(code: "REKEY_FAILED", 
                               message: "PRAGMA rekey failed", 
                               details: String(cString: sqlite3_errmsg(db))))
            sqlite3_close(db)
            return
        }
        
        // Close database
        sqlite3_close(db)
        
        // Verify new key works by reopening
        var verifyDb: OpaquePointer?
        if sqlite3_open(dbPath, &verifyDb) == SQLITE_OK {
            let newKeyQuery = "PRAGMA key = '\(newKey.replacingOccurrences(of: "'", with: "''"))';"
            if sqlite3_exec(verifyDb, newKeyQuery, nil, nil, nil) == SQLITE_OK {
                if sqlite3_exec(verifyDb, "SELECT count(*) FROM sqlite_master;", nil, nil, nil) == SQLITE_OK {
                    sqlite3_close(verifyDb)
                    result(["success": true, "message": "Database rekeyed successfully"])
                    return
                }
            }
            sqlite3_close(verifyDb)
        }
        
        result(FlutterError(code: "VERIFY_FAILED", 
                           message: "Rekey succeeded but verification failed", 
                           details: nil))
    }
    
    /// Verify a key works for the database
    private func verifyKey(dbPath: String, key: String, result: @escaping FlutterResult) {
        var db: OpaquePointer?
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            result(["valid": false, "error": "Cannot open database"])
            sqlite3_close(db)
            return
        }
        
        let keyQuery = "PRAGMA key = '\(key.replacingOccurrences(of: "'", with: "''"))';"
        if sqlite3_exec(db, keyQuery, nil, nil, nil) != SQLITE_OK {
            result(["valid": false, "error": "Cannot set key"])
            sqlite3_close(db)
            return
        }
        
        if sqlite3_exec(db, "SELECT count(*) FROM sqlite_master;", nil, nil, nil) != SQLITE_OK {
            result(["valid": false, "error": "Key is incorrect"])
            sqlite3_close(db)
            return
        }
        
        sqlite3_close(db)
        result(["valid": true])
    }
    
    /// Run integrity check on encrypted database
    private func integrityCheck(dbPath: String, key: String, result: @escaping FlutterResult) {
        var db: OpaquePointer?
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            result(["ok": false, "error": "Cannot open database"])
            sqlite3_close(db)
            return
        }
        
        let keyQuery = "PRAGMA key = '\(key.replacingOccurrences(of: "'", with: "''"))';"
        if sqlite3_exec(db, keyQuery, nil, nil, nil) != SQLITE_OK {
            result(["ok": false, "error": "Cannot set key"])
            sqlite3_close(db)
            return
        }
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) {
                    let checkResult = String(cString: text)
                    sqlite3_finalize(stmt)
                    sqlite3_close(db)
                    result(["ok": checkResult == "ok", "result": checkResult])
                    return
                }
            }
            sqlite3_finalize(stmt)
        }
        
        sqlite3_close(db)
        result(["ok": false, "error": "Integrity check failed"])
    }
}
