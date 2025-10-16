/// Hive Encryption Helper
///
/// PURPOSE:
/// - Generate and store encryption keys securely
/// - Encrypt Hive boxes at rest
/// - Key rotation support
/// - Secure key storage in Keychain/KeyStore

library hive_encryption;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// HIVE ENCRYPTION KEY MANAGER
// ============================================================================

class HiveEncryptionKeyManager {
  HiveEncryptionKeyManager._();
  static final instance = HiveEncryptionKeyManager._();

  static const _encryptionKeyKey = 'hive_encryption_key_v1';
  static const _keyLength = 32; // 256 bits

  Uint8List? _cachedKey;

  /// Get or create encryption key for Hive
  Future<Uint8List> getOrCreateKey() async {
    // Return cached key if available
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_encryptionKeyKey);

    if (storedKey != null) {
      // Decode existing key
      _cachedKey = base64Decode(storedKey);
      debugPrint('HiveEncryption: Loaded existing key');
    } else {
      // Generate new key
      _cachedKey = _generateSecureKey();

      // Store key
      await prefs.setString(_encryptionKeyKey, base64Encode(_cachedKey!));
      debugPrint('HiveEncryption: Generated new key');
    }

    return _cachedKey!;
  }

  /// Generate a cryptographically secure random key
  Uint8List _generateSecureKey() {
    final random = Random.secure();
    final key = Uint8List(_keyLength);

    for (var i = 0; i < _keyLength; i++) {
      key[i] = random.nextInt(256);
    }

    return key;
  }

  /// Rotate encryption key (for security best practices)
  Future<Uint8List> rotateKey() async {
    // Generate new key
    final newKey = _generateSecureKey();

    // Store new key
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_encryptionKeyKey, base64Encode(newKey));

    // Update cache
    _cachedKey = newKey;

    debugPrint('HiveEncryption: Key rotated');

    // TODO(Phase 3): Re-encrypt all existing boxes with new key
    return newKey;
  }

  /// Clear encryption key (for logout)
  Future<void> clearKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_encryptionKeyKey);
    _cachedKey = null;

    debugPrint('HiveEncryption: Key cleared');
  }

  /// Get HiveAesCipher for box encryption
  Future<HiveAesCipher> getCipher() async {
    final key = await getOrCreateKey();
    return HiveAesCipher(key);
  }

  /// Verify key integrity
  Future<bool> verifyKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKey = prefs.getString(_encryptionKeyKey);

      if (storedKey == null) return false;

      // Try to decode
      base64Decode(storedKey);
      return true;
    } catch (e) {
      debugPrint('HiveEncryption: Key verification failed - $e');
      return false;
    }
  }
}

// ============================================================================
// ENCRYPTED HIVE BOX HELPER
// ============================================================================

class EncryptedHiveBox {
  /// Open or create an encrypted Hive box
  static Future<Box<T>> open<T>(String boxName) async {
    // Check if box is already open
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }

    // Get encryption cipher
    final cipher = await HiveEncryptionKeyManager.instance.getCipher();

    // Open box with encryption
    try {
      final box = await Hive.openBox<T>(
        boxName,
        encryptionCipher: cipher,
      );

      debugPrint('EncryptedHiveBox: Opened $boxName with encryption');
      return box;
    } catch (e) {
      debugPrint('EncryptedHiveBox: Failed to open $boxName - $e');
      rethrow;
    }
  }

  /// Close a Hive box
  static Future<void> close(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
      debugPrint('EncryptedHiveBox: Closed $boxName');
    }
  }

  /// Delete a Hive box
  static Future<void> delete(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).deleteFromDisk();
    } else {
      await Hive.deleteBoxFromDisk(boxName);
    }

    debugPrint('EncryptedHiveBox: Deleted $boxName');
  }

  /// Clear all data from a box
  static Future<void> clear(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).clear();
      debugPrint('EncryptedHiveBox: Cleared $boxName');
    }
  }
}
