import 'dart:io' show Platform;

import '../browser/auth_browser_launcher.dart';
import '../config/google_auth_config.dart';
import '../errors/uids_auth_exception.dart';
import '../models/auth_provider.dart';
import '../models/provider_auth_result.dart';
import 'google/google_auth_platform_adapter.dart';
import 'google/google_desktop_auth_adapter.dart';
import 'google/google_mobile_auth_adapter.dart';
import 'provider_auth_adapter.dart';

/// `ProviderAuthAdapter` for Google.
///
/// This class is a thin façade — it delegates **every** call to a
/// [GoogleAuthPlatformAdapter] supplied at construction time.  It contains no
/// `google_sign_in` dependency, no PKCE logic, and no platform `if`-trees.
///
/// Construction:
/// - Use [GoogleAuthAdapter.new] when you want to inject a specific platform
///   adapter (testing, custom platforms, mocks).
/// - Use [GoogleAuthAdapter.fromPlatform] for the common case — it picks the
///   right concrete adapter based on the host OS.
final class GoogleAuthAdapter implements ProviderAuthAdapter {
  /// Inject a specific platform adapter.  Prefer this in tests.
  const GoogleAuthAdapter({required GoogleAuthPlatformAdapter platformAdapter})
      : _platform = platformAdapter;

  /// Convenience factory — selects the platform adapter based on the host OS.
  ///
  /// - Android / iOS              → [GoogleMobileAuthAdapter] (uses `google_sign_in`;
  ///   [browserLauncher] is ignored on mobile since the native plugin handles UI)
  /// - Windows / macOS / Linux    → [GoogleDesktopAuthAdapter] (PKCE + [browserLauncher])
  ///
  /// This factory is the **only** place in the SDK that performs Google
  /// platform detection.
  factory GoogleAuthAdapter.fromPlatform({
    required GoogleAuthConfig config,
    AuthBrowserLauncher? browserLauncher,
  }) {
    return GoogleAuthAdapter(
      platformAdapter: _selectPlatform(config, browserLauncher),
    );
  }

  final GoogleAuthPlatformAdapter _platform;

  // ── ProviderAuthAdapter ───────────────────────────────────────────────────

  @override
  AuthProvider get provider => AuthProvider.google;

  @override
  Future<ProviderAuthResult> signIn({List<String> scopes = const []}) =>
      _platform.signIn(scopes: scopes);

  @override
  Future<ProviderAuthResult> refresh({List<String> scopes = const []}) =>
      _platform.refresh(scopes: scopes);

  @override
  Future<void> signOut() => _platform.signOut();

  // ── Internals ─────────────────────────────────────────────────────────────

  static GoogleAuthPlatformAdapter _selectPlatform(
    GoogleAuthConfig config,
    AuthBrowserLauncher? launcher,
  ) {
    if (Platform.isAndroid || Platform.isIOS) {
      return GoogleMobileAuthAdapter(config: config);
    }
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return GoogleDesktopAuthAdapter(
        config: config,
        browserLauncher: launcher,
      );
    }
    throw const UidsProviderSignInException(
      'Google sign-in is not supported on this platform.',
    );
  }
}
