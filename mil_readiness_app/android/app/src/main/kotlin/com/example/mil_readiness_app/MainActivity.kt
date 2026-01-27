package com.example.mil_readiness_app

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import net.sqlcipher.database.SQLiteDatabase
import net.sqlcipher.database.SQLiteException
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "mil_readiness_app/sqlcipher"
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize SQLCipher library
        SQLiteDatabase.loadLibs(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "rekeyDatabase" -> {
                    val dbPath = call.argument<String>("dbPath")
                    val oldKey = call.argument<String>("oldKey")
                    val newKey = call.argument<String>("newKey")
                    
                    if (dbPath == null || oldKey == null || newKey == null) {
                        result.error("INVALID_ARGS", "Missing dbPath, oldKey, or newKey", null)
                        return@setMethodCallHandler
                    }
                    
                    rekeyDatabase(dbPath, oldKey, newKey, result)
                }
                "verifyKey" -> {
                    val dbPath = call.argument<String>("dbPath")
                    val key = call.argument<String>("key")
                    
                    if (dbPath == null || key == null) {
                        result.error("INVALID_ARGS", "Missing dbPath or key", null)
                        return@setMethodCallHandler
                    }
                    
                    verifyKey(dbPath, key, result)
                }
                "integrityCheck" -> {
                    val dbPath = call.argument<String>("dbPath")
                    val key = call.argument<String>("key")
                    
                    if (dbPath == null || key == null) {
                        result.error("INVALID_ARGS", "Missing dbPath or key", null)
                        return@setMethodCallHandler
                    }
                    
                    integrityCheck(dbPath, key, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    /**
     * Rekey database using PRAGMA rekey
     *
     * Steps:
     * 1. Open database with old key
     * 2. Execute PRAGMA rekey = 'new_key'
     * 3. Close database
     * 4. Verify new key works
     */
    private fun rekeyDatabase(
        dbPath: String, 
        oldKey: String, 
        newKey: String, 
        result: MethodChannel.Result
    ) {
        var db: SQLiteDatabase? = null
        
        try {
            // Open database with old key
            db = SQLiteDatabase.openDatabase(dbPath, oldKey, null, SQLiteDatabase.OPEN_READWRITE)
            
            // Verify we can read the database
            db.rawQuery("SELECT count(*) FROM sqlite_master", null).use { cursor ->
                if (!cursor.moveToFirst()) {
                    result.error("KEY_INVALID", "Old key is invalid - cannot read database", null)
                    return
                }
            }
            
            // Execute PRAGMA rekey with new key
            db.rawExecSQL("PRAGMA rekey = '${newKey.replace("'", "''")}'")
            
            // Close database
            db.close()
            db = null
            
            // Verify new key works by reopening
            val verifyDb = SQLiteDatabase.openDatabase(dbPath, newKey, null, SQLiteDatabase.OPEN_READONLY)
            verifyDb.rawQuery("SELECT count(*) FROM sqlite_master", null).use { cursor ->
                if (cursor.moveToFirst()) {
                    verifyDb.close()
                    result.success(mapOf("success" to true, "message" to "Database rekeyed successfully"))
                    return
                }
            }
            verifyDb.close()
            result.error("VERIFY_FAILED", "Rekey succeeded but verification failed", null)
            
        } catch (e: SQLiteException) {
            result.error("REKEY_FAILED", "PRAGMA rekey failed: ${e.message}", null)
        } catch (e: Exception) {
            result.error("UNKNOWN_ERROR", "Unexpected error: ${e.message}", null)
        } finally {
            db?.close()
        }
    }
    
    /**
     * Verify a key works for the database
     */
    private fun verifyKey(dbPath: String, key: String, result: MethodChannel.Result) {
        try {
            val db = SQLiteDatabase.openDatabase(dbPath, key, null, SQLiteDatabase.OPEN_READONLY)
            db.rawQuery("SELECT count(*) FROM sqlite_master", null).use { cursor ->
                if (cursor.moveToFirst()) {
                    db.close()
                    result.success(mapOf("valid" to true))
                    return
                }
            }
            db.close()
            result.success(mapOf("valid" to false, "error" to "Cannot read database"))
        } catch (e: Exception) {
            result.success(mapOf("valid" to false, "error" to e.message))
        }
    }
    
    /**
     * Run integrity check on encrypted database
     */
    private fun integrityCheck(dbPath: String, key: String, result: MethodChannel.Result) {
        try {
            val db = SQLiteDatabase.openDatabase(dbPath, key, null, SQLiteDatabase.OPEN_READONLY)
            db.rawQuery("PRAGMA integrity_check", null).use { cursor ->
                if (cursor.moveToFirst()) {
                    val checkResult = cursor.getString(0)
                    db.close()
                    result.success(mapOf("ok" to (checkResult == "ok"), "result" to checkResult))
                    return
                }
            }
            db.close()
            result.success(mapOf("ok" to false, "error" to "Integrity check failed"))
        } catch (e: Exception) {
            result.success(mapOf("ok" to false, "error" to e.message))
        }
    }
}
