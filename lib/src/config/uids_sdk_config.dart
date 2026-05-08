import 'google_auth_config.dart';
import 'microsoft_auth_config.dart';

/// Top-level configuration passed to [UidsAuthSdk.initialize].
///
/// All credentials and URLs are supplied by the consumer app — the SDK never
/// hard-codes any values.
final class UidsSdkConfig {
  const UidsSdkConfig({
    required this.apiBaseUrl,
    required this.authBaseUrl,
    required this.clientId,
    this.clientSecret,
    this.audience,
    this.autoRefresh = true,
    this.refreshBeforeExpiry = const Duration(minutes: 5),
    this.google,
    this.microsoft,
  });

  /// Base URL for the consumer's main API (used for device endpoints, etc.).
  final Uri apiBaseUrl;

  /// Base URL for the authentication/token service.
  final Uri authBaseUrl;

  /// OAuth 2.0 client ID registered with the backend.
  final String clientId;

  /// OAuth 2.0 client secret (omit for public clients / PKCE flows).
  final String? clientSecret;

  /// OAuth 2.0 audience claim expected by the backend.
  final String? audience;

  /// Whether the SDK should automatically schedule a token refresh before
  /// expiry.  Set to `false` if you prefer manual refresh via
  /// [UidsAuthSdk.refreshSession].
  final bool autoRefresh;

  /// How far before [AuthSession.expiresAt] the SDK proactively refreshes the
  /// token when [autoRefresh] is `true`.
  final Duration refreshBeforeExpiry;

  /// Google Sign-In configuration.  Required if you call
  /// [UidsAuthSdk.signInWithProvider] with [AuthProvider.google].
  final GoogleAuthConfig? google;

  /// Microsoft authentication configuration.  Required if you call
  /// [UidsAuthSdk.signInWithProvider] with [AuthProvider.microsoft].
  final MicrosoftAuthConfig? microsoft;
}
