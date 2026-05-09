import '../config/uids_sdk_config.dart';
import '../models/auth_provider.dart';
import '../models/auth_session.dart';
import '../models/device_models.dart';
import 'uids_auth_sdk_impl.dart';

/// Public facade for the UIDS Auth SDK.
///
/// The API is split into two independent flows:
///
/// - **Authentication** — provider sign-in, session lifecycle, refresh.
/// - **Device registration** — register / update / unregister a device.
///
/// The two flows share an access token but are otherwise independently
/// composable.  Sign-in does not register a device; signing out does not
/// unregister or clear a device.  Compose them at the app layer however your
/// product needs.
///
/// Obtain an instance via [UidsAuthSdk.create] and call [initialize] before
/// using any other method.
abstract interface class UidsAuthSdk {
  /// Creates a new SDK instance backed by platform secure storage.
  factory UidsAuthSdk.create() => UidsAuthSdkImpl();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize(UidsSdkConfig config);

  // ── Authentication ────────────────────────────────────────────────────────

  /// Interactive sign-in with the given provider.
  Future<AuthSession> signInWithProvider({
    required AuthProvider provider,
    List<String> scopes = const ['openid', 'email', 'profile'],
  });

  /// Silently re-acquires a provider credential and exchanges it for a fresh
  /// backend session.  Falls back to throwing — call [signInWithProvider] if
  /// the provider has no cached account.
  Future<AuthSession> refreshProviderSession({
    required AuthProvider provider,
    List<String> scopes = const ['openid', 'email', 'profile'],
  });

  /// Signs the user out of the provider and clears the SDK session.
  ///
  /// Does **not** clear or unregister the device cache.  Call
  /// [unregisterDevice] or [clearAll] separately if you also want to detach
  /// the device.
  Future<void> signOut();

  // ── Session ───────────────────────────────────────────────────────────────

  Future<AuthSession?> currentSession();

  Future<AuthSession> getValidSession();

  Future<String> accessToken();

  Future<Map<String, String>> authHeaders();

  Future<AuthSession> refreshSession({bool force = false});

  Future<bool> isSignedIn();

  // ── Device ────────────────────────────────────────────────────────────────

  Future<RegisteredDevice> registerDevice(DeviceRegisterRequest request);

  Future<RegisteredDevice> ensureDeviceRegistered(
    DeviceRegisterRequest request,
  );

  Future<RegisteredDevice?> currentDevice();

  Future<RegisteredDevice> updateDevice(DeviceUpdateRequest request);

  Future<void> unregisterDevice();

  // ── Cache ─────────────────────────────────────────────────────────────────

  /// Clears the in-memory caches for both session and device.  Secure storage
  /// is untouched so the next read can rehydrate from disk.
  Future<void> clearMemoryCache();

  /// Clears persisted state for both session and device locally.  Does not
  /// hit the backend.
  Future<void> clearAll();

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<AuthSession?> get sessionChanges;

  Stream<RegisteredDevice?> get deviceChanges;
}
