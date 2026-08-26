import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/services/secure_storage.dart';

class VaultLockedException implements Exception {
  const VaultLockedException();
}

class BiometricUnlockException implements Exception {
  const BiometricUnlockException(this.message);
  final String message;

  @override
  String toString() => message;
}

class VaultService {
  VaultService(
    this._database, {
    FlutterSecureStorage? secureStorage,
    String vaultId = 'conduit',
  }) : _vaultId = vaultId,
       _biometricKey =
           '${_biometricKeyPrefix}_${base64UrlEncode(utf8.encode(vaultId))}',
       _secureStorage = secureStorage ?? appSecureStorage;

  static const _biometricKeyPrefix = 'conduit_vault_data_key';

  /// Keychain prefix of the removed cloud-sync passphrase; unlock deletes any
  /// entry left behind by earlier releases.
  static const _legacySyncPassphraseKeyPrefix = 'conduit_vault_sync_passphrase';
  static const _iterations = 310000;
  static String _key(String prefix, String vaultId) =>
      '${prefix}_${base64UrlEncode(utf8.encode(vaultId))}';

  /// Moves vault-scoped keychain entries when a database file is relocated.
  static Future<void> relocateStoredKeys({
    required String oldVaultId,
    required String newVaultId,
    FlutterSecureStorage? secureStorage,
  }) async {
    final storage = secureStorage ?? appSecureStorage;
    final oldKey = _key(_biometricKeyPrefix, oldVaultId);
    final newKey = _key(_biometricKeyPrefix, newVaultId);
    final value = await storage.read(key: oldKey);
    if (value != null) {
      await storage.write(key: newKey, value: value);
      await storage.delete(key: oldKey);
    }
  }

  final AppDatabase _database;
  final FlutterSecureStorage _secureStorage;
  final String _vaultId;
  final String _biometricKey;
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _dataKey;

  bool get isUnlocked => _dataKey != null;

  /// Removes the sync passphrase an earlier release stored in the keychain.
  Future<void> _deleteLegacySyncPassphrase() async {
    try {
      await _secureStorage.delete(
        key: _key(_legacySyncPassphraseKeyPrefix, _vaultId),
      );
    } catch (_) {
      // Best effort: a missing or locked keychain must not block unlock.
    }
  }

  Future<bool> hasVault() async =>
      (await _database.select(_database.vaultMetadata).get()).isNotEmpty;

  Future<bool> isBiometricUnlockEnabled() async =>
      await _secureStorage.containsKey(key: _biometricKey);

  Future<void> create(String password) async {
    final salt = _randomBytes(16);
    final wrappingKey = await _deriveKey(password, salt);
    final dataKey = await _cipher.newSecretKey();
    final dataKeyBytes = await dataKey.extractBytes();
    final wrapped = await _encryptBytes(dataKeyBytes, wrappingKey, 'vault-key');
    final verifier = await _encryptBytes(
      utf8.encode('Conduit vault v1'),
      dataKey,
      'verifier',
    );
    await _database
        .into(_database.vaultMetadata)
        .insert(
          VaultMetadataCompanion.insert(
            formatVersion: 1,
            salt: _encode(salt),
            wrappedDataKey: _encode(_pack(wrapped)),
            wrappedDataKeyNonce: _encode(wrapped.nonce),
            verifier: _encode(_pack(verifier)),
            verifierNonce: _encode(verifier.nonce),
            createdAt: DateTime.now().toUtc(),
          ),
        );
    _dataKey = dataKey;
  }

  Future<bool> unlockWithPassword(String password) async {
    final metadata = await _metadata();
    try {
      final wrappingKey = await _deriveKey(password, _decode(metadata.salt));
      final bytes = await _decryptBytes(
        _decode(metadata.wrappedDataKey),
        _decode(metadata.wrappedDataKeyNonce),
        wrappingKey,
        'vault-key',
      );
      final candidate = SecretKey(bytes);
      await _decryptBytes(
        _decode(metadata.verifier),
        _decode(metadata.verifierNonce),
        candidate,
        'verifier',
      );
      _dataKey = candidate;
      await _deleteLegacySyncPassphrase();
      return true;
    } on SecretBoxAuthenticationError {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  Future<bool> unlockWithBiometrics() async {
    final key = await _secureStorage.read(key: _biometricKey);
    if (key == null) {
      throw const BiometricUnlockException(
        'Biometric unlock is not enabled. Unlock with your vault password, then enable it in Settings.',
      );
    }
    final authentication = LocalAuthentication();
    // deviceOwnerAuthentication accepts Touch ID, Apple Watch, or the Mac
    // login password — no biometric hardware required.
    if (!await authentication.isDeviceSupported()) {
      throw const BiometricUnlockException(
        'Device unlock is unavailable. Set a login password for this Mac, then try again.',
      );
    }
    try {
      final authenticated = await authentication.authenticate(
        localizedReason: 'Unlock your Conduit vault',
        biometricOnly: false,
      );
      if (!authenticated) {
        throw const BiometricUnlockException(
          'Biometric authentication was cancelled.',
        );
      }
      _dataKey = SecretKey(_decode(key));
    } on BiometricUnlockException {
      rethrow;
    } catch (error) {
      throw BiometricUnlockException('Biometric unlock failed: $error');
    }
    await _deleteLegacySyncPassphrase();
    return true;
  }

  /// Prompts for biometrics once, then stores the data key for future unlocks.
  /// Does not enable on failure (nothing is written).
  Future<void> enableBiometricUnlock() async {
    final key = _requireKey();
    final authentication = LocalAuthentication();
    if (!await authentication.isDeviceSupported()) {
      throw const BiometricUnlockException(
        'Device unlock is unavailable. Set a login password for this Mac, then try again.',
      );
    }
    try {
      final authenticated = await authentication.authenticate(
        localizedReason: 'Enable biometric unlock for Conduit',
        biometricOnly: false,
      );
      if (!authenticated) {
        throw const BiometricUnlockException(
          'Biometric authentication was cancelled.',
        );
      }
    } on BiometricUnlockException {
      rethrow;
    } catch (error) {
      throw BiometricUnlockException('Biometric setup failed: $error');
    }
    await _secureStorage.write(
      key: _biometricKey,
      value: _encode(await key.extractBytes()),
    );
  }

  Future<void> disableBiometricUnlock() =>
      _secureStorage.delete(key: _biometricKey);

  Future<void> lock() async {
    _dataKey = null;
  }

  /// Rewraps the existing data key with [newPassword]. Stored vault data and
  /// biometric access stay valid because the data key itself does not change.
  Future<void> changePassword(String newPassword) async {
    final dataKey = _requireKey();
    final metadata = await _metadata();
    final salt = _randomBytes(16);
    final wrappingKey = await _deriveKey(newPassword, salt);
    final wrapped = await _encryptBytes(
      await dataKey.extractBytes(),
      wrappingKey,
      'vault-key',
    );
    await (_database.update(
      _database.vaultMetadata,
    )..where((table) => table.id.equals(metadata.id))).write(
      VaultMetadataCompanion(
        salt: Value(_encode(salt)),
        wrappedDataKey: Value(_encode(_pack(wrapped))),
        wrappedDataKeyNonce: Value(_encode(wrapped.nonce)),
      ),
    );
  }

  Future<EncryptedValue> encrypt(
    String value, {
    required String context,
  }) async {
    final box = await _encryptBytes(utf8.encode(value), _requireKey(), context);
    return EncryptedValue(
      bytes: _encode(_pack(box)),
      nonce: _encode(box.nonce),
    );
  }

  Future<String> decrypt(
    EncryptedValue value, {
    required String context,
  }) async {
    final clear = await _decryptBytes(
      _decode(value.bytes),
      _decode(value.nonce),
      _requireKey(),
      context,
    );
    return utf8.decode(clear);
  }

  /// Version of the portable envelope written by [encryptPortable]. Readers
  /// accept every version up to this one.
  static const portableFormatVersion = 1;

  /// Encrypts a portable archive with the supplied vault password instead of
  /// this device's data key, so another vault can import it.
  Future<String> encryptPortable(String value, String password) async {
    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt);
    final box = await _encryptBytes(
      utf8.encode(value),
      key,
      'portable-archive',
    );
    return jsonEncode({
      'version': portableFormatVersion,
      'salt': _encode(salt),
      'ciphertext': _encode(_pack(box)),
      'nonce': _encode(box.nonce),
    });
  }

  Future<String> decryptPortable(String archive, String password) async {
    final value = jsonDecode(archive) as Map<String, dynamic>;
    final version = value['version'];
    if (version is! int || version < 1 || version > portableFormatVersion) {
      throw const FormatException('Unsupported archive version.');
    }
    final key = await _deriveKey(password, _decode(value['salt'] as String));
    final clear = await _decryptBytes(
      _decode(value['ciphertext'] as String),
      _decode(value['nonce'] as String),
      key,
      'portable-archive',
    );
    return utf8.decode(clear);
  }

  Future<VaultMetadataData> _metadata() async =>
      (await _database.select(_database.vaultMetadata).getSingle());

  SecretKey _requireKey() => _dataKey ?? (throw const VaultLockedException());

  Future<SecretKey> _deriveKey(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Future<SecretBox> _encryptBytes(
    List<int> bytes,
    SecretKey key,
    String context,
  ) => _cipher.encrypt(bytes, secretKey: key, aad: utf8.encode(context));

  Future<List<int>> _decryptBytes(
    List<int> bytes,
    List<int> nonce,
    SecretKey key,
    String context,
  ) => _cipher.decrypt(
    SecretBox(
      bytes.sublist(0, bytes.length - 16),
      nonce: nonce,
      mac: Mac(bytes.sublist(bytes.length - 16)),
    ),
    secretKey: key,
    aad: utf8.encode(context),
  );

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => Random.secure().nextInt(256));
  List<int> _pack(SecretBox box) => [...box.cipherText, ...box.mac.bytes];
  String _encode(List<int> bytes) => base64UrlEncode(bytes);
  List<int> _decode(String value) =>
      base64Url.decode(base64Url.normalize(value));
}

class EncryptedValue {
  const EncryptedValue({required this.bytes, required this.nonce});
  final String bytes;
  final String nonce;
}
