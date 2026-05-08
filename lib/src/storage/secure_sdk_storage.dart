import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sdk_storage.dart';

/// [SdkStorage] backed by [FlutterSecureStorage].
///
/// On Android data is encrypted with AES-256 in the Android Keystore.
/// On iOS data is stored in the Keychain.
/// On desktop (macOS/Linux/Windows) platform-specific secure stores are used.
final class SecureSdkStorage implements SdkStorage {
  SecureSdkStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
