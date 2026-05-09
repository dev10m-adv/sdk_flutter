/// GitHub OAuth App authentication configuration.
final class GitHubAuthConfig {
  const GitHubAuthConfig({
    required this.clientId,
    required this.clientSecret,
    this.redirectUri,
  });

  /// GitHub OAuth App client ID.
  final String clientId;

  /// GitHub OAuth App client secret.
  /// Required for the authorization-code token exchange on all platforms.
  final String clientSecret;

  /// Redirect URI registered in the GitHub OAuth App settings.
  ///
  /// Desktop: a loopback URL with an explicit port and path,
  ///   e.g. `http://localhost:9100/auth`
  /// Mobile:  a custom scheme deep link,
  ///   e.g. `com.example.app://auth/github`
  final String? redirectUri;
}
