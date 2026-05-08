import '../config/microsoft_auth_config.dart';
import '../models/auth_provider.dart';
import '../models/provider_auth_result.dart';
import 'provider_auth_adapter.dart';

/// Microsoft (Entra ID / Azure AD) authentication adapter.
///
/// This is a placeholder implementation.  Wire up your preferred MSAL Flutter
/// package (e.g. `msal_flutter`, `aad_oauth`) inside [signIn].
///
/// The adapter does NOT call the backend and does NOT store any tokens.
final class MicrosoftAuthAdapter implements ProviderAuthAdapter {
  MicrosoftAuthAdapter({required MicrosoftAuthConfig config})
      : _config = config;

  final MicrosoftAuthConfig _config;

  @override
  AuthProvider get provider => AuthProvider.microsoft;

  @override
  Future<ProviderAuthResult> signIn({
    List<String> scopes = const [],
  }) async {
    // ─────────────────────────────────────────────────────────────────────
    // TODO: Replace this stub with your MSAL / AAD OAuth implementation.
    //
    // Example using the `aad_oauth` package:
    //
    //   final oauth = AadOAuth(Config(
    //     tenant: _config.tenantId,
    //     clientId: _config.clientId,
    //     redirectUri: _config.redirectUri ?? 'msauth://callback',
    //     scope: scopes.join(' '),
    //   ));
    //   await oauth.login();
    //   final idToken = await oauth.getIdToken();
    //   if (idToken == null) throw UidsProviderCancelledException();
    //   return ProviderAuthResult(
    //     provider: AuthProvider.microsoft,
    //     idToken: idToken,
    //     scopes: scopes,
    //   );
    // ─────────────────────────────────────────────────────────────────────

    throw UnimplementedError(
      'MicrosoftAuthAdapter.signIn() is not implemented. '
      'Wire up your MSAL / AAD OAuth library here. '
      'Config: clientId=${_config.clientId}, tenantId=${_config.tenantId}',
    );
  }

  @override
  Future<ProviderAuthResult> refresh({
    List<String> scopes = const [],
  }) async {
    // ─────────────────────────────────────────────────────────────────────
    // TODO: Replace this stub with a silent token refresh against MSAL.
    //
    // Example using the `aad_oauth` package:
    //
    //   final oauth = AadOAuth(Config(
    //     tenant: _config.tenantId,
    //     clientId: _config.clientId,
    //     redirectUri: _config.redirectUri ?? 'msauth://callback',
    //     scope: scopes.join(' '),
    //   ));
    //   final idToken = await oauth.getIdToken(); // returns cached or refreshed
    //   if (idToken == null) {
    //     throw const UidsProviderSignInException(
    //       'No cached Microsoft account — interactive sign-in required.',
    //     );
    //   }
    //   return ProviderAuthResult(
    //     provider: AuthProvider.microsoft,
    //     idToken: idToken,
    //     scopes: scopes,
    //   );
    // ─────────────────────────────────────────────────────────────────────

    throw UnimplementedError(
      'MicrosoftAuthAdapter.refresh() is not implemented. '
      'Wire up your MSAL / AAD OAuth library here. '
      'Config: clientId=${_config.clientId}, tenantId=${_config.tenantId}',
    );
  }

  @override
  Future<void> signOut() async {
    // TODO: Call your MSAL library sign-out method here.
  }
}
