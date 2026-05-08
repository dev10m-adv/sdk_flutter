import 'auth_provider.dart';

/// Raw result returned by a provider adapter after sign-in.
/// This is an internal model — never exposed in the public API.
final class ProviderAuthResult {
  const ProviderAuthResult({
    required this.provider,
    required this.idToken,
    this.accessToken,
    this.serverAuthCode,
    this.scopes = const [],
  });

  /// The identity provider that produced this result.
  final AuthProvider provider;

  /// ID token (JWT) issued by the provider.
  final String idToken;

  /// Provider access token (optional — backend may not need it).
  final String? accessToken;

  /// Server auth code for backend-side token exchange (Google-specific).
  final String? serverAuthCode;

  /// Granted scopes.
  final List<String> scopes;
}
