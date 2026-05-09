/// Minimal key/value storage abstraction used by the SDK.
///
/// Implementations must be safe to call from any isolate.
abstract interface class SdkStorage {
  /// Returns the stored string for [key], or `null` if absent.
  Future<String?> read(String key);

  /// Persists [value] under [key], overwriting any existing value.
  Future<void> write(String key, String value);

  /// Removes the value for [key].  No-op if the key does not exist.
  Future<void> delete(String key);

  /// Removes ALL keys managed by this storage instance.
  Future<void> deleteAll();
}
