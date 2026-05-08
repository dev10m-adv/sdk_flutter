/// Centralised storage key registry.
///
/// All keys used by the SDK are defined here — no scattered magic strings.
abstract final class StorageKeys {
  StorageKeys._();

  /// Serialised [AuthSession] JSON object.
  static const String session = 'uids_auth_sdk.session';

  /// Serialised [RegisteredDevice] JSON object.
  static const String device = 'uids_auth_sdk.device';
}
