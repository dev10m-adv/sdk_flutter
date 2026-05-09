/// Microsoft (Entra ID / Azure AD) authentication configuration.
final class MicrosoftAuthConfig {
  const MicrosoftAuthConfig({
    required this.clientId,
    this.tenantId = 'common',
    this.redirectUri,
    this.authority,
  });

  /// Azure AD application (client) ID.
  final String clientId;

  /// Tenant ID or well-known authority alias.
  /// Use `'common'` for multi-tenant, `'organizations'` for work accounts only,
  /// `'consumers'` for personal accounts, or a specific tenant GUID/domain.
  final String tenantId;

  /// Redirect URI registered in the Azure portal.
  /// Example: `msauth://com.example.app/callback`
  final String? redirectUri;

  /// Full authority URL override.
  /// Defaults to `https://login.microsoftonline.com/{tenantId}`.
  final String? authority;

  String get resolvedAuthority =>
      authority ?? 'https://login.microsoftonline.com/$tenantId';
}
