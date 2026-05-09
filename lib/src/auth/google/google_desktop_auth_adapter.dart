import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../auth_callback_page.dart';
import '../../config/google_auth_config.dart';
import '../../errors/uids_auth_exception.dart';
import '../../models/auth_provider.dart';
import '../../models/provider_auth_result.dart';
import 'google_auth_platform_adapter.dart';

/// Google sign-in for Windows / macOS / Linux using the OAuth 2.0
/// Authorization Code flow with PKCE and a transient localhost loopback
/// listener.
///
/// Flow:
/// 1. Generate `code_verifier`, `code_challenge` (S256), `state`.
/// 2. Bind a one-shot HTTP server on the configured loopback port.
/// 3. Open the system browser at Google's authorize endpoint.
/// 4. Receive the redirect, validate `state`, extract `code`.
/// 5. POST to Google's token endpoint with `code` + `code_verifier`.
/// 6. Return [ProviderAuthResult] (id_token + access_token).
///
/// The loopback server is **always** closed in a `finally` block, regardless
/// of success, cancel, or error.  No tokens are persisted; the refresh token
/// (when granted) is held in memory for the lifetime of the adapter so that
/// [refresh] can run without UI.
final class GoogleDesktopAuthAdapter implements GoogleAuthPlatformAdapter {
  GoogleDesktopAuthAdapter({
    required GoogleAuthConfig config,
    http.Client? httpClient,
    Future<void> Function(Uri url)? launchUrl,
  }) : _config = config,
       _http = httpClient ?? http.Client(),
       _launchUrl = launchUrl ?? _defaultLaunchUrl;

  static const _authorizeEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  /// Maximum time we'll wait for the user to complete the browser flow before
  /// giving up and tearing the loopback server down.
  static const _flowTimeout = Duration(minutes: 5);

  final GoogleAuthConfig _config;
  final http.Client _http;
  final Future<void> Function(Uri url) _launchUrl;

  /// Held in memory only — never persisted.  Set after a successful sign-in
  /// so that [refresh] can run without UI.
  String? _refreshToken;

  // ── GoogleAuthPlatformAdapter ────────────────────────────────────────────

  @override
  Future<ProviderAuthResult> signIn({List<String> scopes = const []}) async {
    final clientId = _requireClientId();
    final redirectUri = _resolveRedirectUri();
    final effectiveScopes = _withOpenIdScopes(scopes);

    final verifier = _randomUrlSafe(64);
    final challenge = _s256Challenge(verifier);
    final state = _randomUrlSafe(32);

    HttpServer? server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        redirectUri.port,
        shared: true,
      );
      final authorizeUrl = Uri.parse(_authorizeEndpoint).replace(
        queryParameters: <String, String>{
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUri.toString(),
          'scope': effectiveScopes.join(' '),
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'state': state,
          'access_type': 'offline',
          'prompt': 'consent',
          'include_granted_scopes': 'true',
        },
      );

      // Best-effort browser launch.  If it fails, the user can paste the URL
      // manually — but we still surface the error.
      try {
        await _launchUrl(authorizeUrl);
      } catch (e) {
        throw UidsProviderSignInException(
          'Failed to open the system browser for Google sign-in.',
          cause: e,
        );
      }

      final code = await _awaitCallback(
        server: server,
        expectedState: state,
        expectedPath: redirectUri.path.isEmpty ? '/' : redirectUri.path,
      );

      final result = await _exchangeCode(
        code: code,
        verifier: verifier,
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: effectiveScopes,
      );

      return result;
    } on UidsAuthException {
      print('GoogleDesktopAuthAdapter.signIn() error:');
      rethrow;
    } catch (e) {
      print('GoogleDesktopAuthAdapter.signIn() unexpected error: $e');
      throw UidsProviderSignInException(
        'Google desktop sign-in failed.',
        cause: e,
      );
    } finally {
      // Always close the loopback server, no matter what.
      await server?.close(force: true);
    }
  }

  @override
  Future<ProviderAuthResult> refresh({List<String> scopes = const []}) async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      throw const UidsProviderSignInException(
        'No cached Google refresh token — interactive sign-in required.',
      );
    }

    final clientId = _requireClientId();
    final clientSecret = _resolveClientSecret();
    final effectiveScopes = _withOpenIdScopes(scopes);

    try {
      final response = await _http.post(
        Uri.parse(_tokenEndpoint),
        body: <String, String>{
          'client_id': clientId,
          if (clientSecret != null) 'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode != 200) {
        // Refresh tokens can be revoked on Google's side.  Drop the cached
        // value and tell the caller to re-prompt.
        _refreshToken = null;
        throw UidsProviderSignInException(
          'Google refresh failed (HTTP ${response.statusCode}): '
          '${_describeError(response.body)}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final idToken = json['id_token'] as String?;
      if (idToken == null) {
        throw const UidsProviderSignInException(
          'Google refresh returned no id_token.',
        );
      }

      // Google may rotate the refresh token.  If a new one comes back, keep
      // it; otherwise the old one stays valid.
      final rotated = json['refresh_token'] as String?;
      if (rotated != null) _refreshToken = rotated;

      return ProviderAuthResult(
        provider: AuthProvider.google,
        idToken: idToken,
        accessToken: json['access_token'] as String?,
        scopes: effectiveScopes,
      );
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException(
        'Google silent refresh failed.',
        cause: e,
      );
    }
  }

  @override
  Future<void> signOut() async {
    final token = _refreshToken;
    _refreshToken = null;
    if (token == null) return;

    // Best-effort revocation.  Do not throw if Google rejects it.
    try {
      await _http.post(
        Uri.parse(_revokeEndpoint),
        body: <String, String>{'token': token},
      );
    } catch (_) {
      // Ignored — the local credential has already been cleared.
    }
  }

  // ── Loopback callback ────────────────────────────────────────────────────

  Future<String> _awaitCallback({
    required HttpServer server,
    required String expectedState,
    required String expectedPath,
  }) async {
    try {
      final request = await server.first.timeout(_flowTimeout);
      final params = request.uri.queryParameters;

      // Validate redirect path so we don't surface tokens for a stray hit.
      if (request.uri.path != expectedPath) {
        _writeBrowserResponse(
          request,
          status: HttpStatus.notFound,
          body: 'Unknown path.',
        );
        throw const UidsProviderSignInException(
          'Google redirect arrived on the wrong path.',
        );
      }

      // Validate state (CSRF protection).
      if (params['state'] != expectedState) {
        _writeBrowserResponse(
          request,
          status: HttpStatus.badRequest,
          body: 'Invalid state.',
        );
        throw const UidsProviderSignInException(
          'Google redirect failed state validation.',
        );
      }

      // Surface provider-side errors (`error=access_denied`, etc.).
      final error = params['error'];
      if (error != null) {
        _writeBrowserResponse(
          request,
          status: HttpStatus.badRequest,
          body: 'Sign-in cancelled or rejected: $error',
        );
        if (error == 'access_denied') {
          throw const UidsProviderCancelledException();
        }
        throw UidsProviderSignInException('Google sign-in error: $error.');
      }

      final code = params['code'];
      if (code == null || code.isEmpty) {
        _writeBrowserResponse(
          request,
          status: HttpStatus.badRequest,
          body: 'Missing authorization code.',
        );
        throw const UidsProviderSignInException(
          'Google redirect did not include an authorization code.',
        );
      }

      _writeBrowserResponse(
        request,
        status: HttpStatus.ok,
        body:
            'Sign-in complete. You can close this window and return to the app.',
      );
      return code;
    } on TimeoutException {
      throw const UidsProviderSignInException(
        'Google sign-in timed out — the browser callback never arrived.',
      );
    }
  }

  void _writeBrowserResponse(
    HttpRequest request, {
    required int status,
    required String body,
  }) {
    final isSuccess = status >= 200 && status < 300;
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(
        buildAuthCallbackHtml(
          title: isSuccess ? 'Sign-in Complete' : 'Sign-in Failed',
          message: body,
          isSuccess: isSuccess,
        ),
      );
    // Closing the response is fire-and-forget — the server is closed in the
    // outer `finally`.
    request.response.close();
  }

  // ── Token exchange ───────────────────────────────────────────────────────

  Future<ProviderAuthResult> _exchangeCode({
    required String code,
    required String verifier,
    required String clientId,
    required Uri redirectUri,
    required List<String> scopes,
  }) async {
    final clientSecret = _resolveClientSecret();

    final response = await _http.post(
      Uri.parse(_tokenEndpoint),
      body: <String, String>{
        'client_id': clientId,
        // Google's "Desktop app" / "Web application" OAuth client types
        // require client_secret on the token endpoint even when PKCE is
        // used.  Omit the field only for iOS/Android client types.
        if (clientSecret != null) 'client_secret': clientSecret,
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirectUri.toString(),
      },
    );

    if (response.statusCode != 200) {
      throw UidsProviderSignInException(
        'Google token exchange failed (HTTP ${response.statusCode}): '
        '${_describeError(response.body)}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = json['id_token'] as String?;
    if (idToken == null) {
      throw const UidsProviderSignInException(
        'Google token exchange returned no id_token.',
      );
    }

    _refreshToken = json['refresh_token'] as String?;

    return ProviderAuthResult(
      provider: AuthProvider.google,
      idToken: idToken,
      accessToken: json['access_token'] as String?,
      scopes: scopes,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _requireClientId() {
    final clientId = _config.desktopClientId ?? _config.webClientId;
    if (clientId == null || clientId.isEmpty) {
      throw const UidsProviderSignInException(
        'Google desktop sign-in requires desktopClientId or webClientId in '
        'GoogleAuthConfig.',
      );
    }
    return clientId;
  }

  /// Returns the configured client secret, or `null` if none was supplied.
  ///
  /// Required for Desktop app / Web application OAuth client types; omitted
  /// for iOS/Android client types (which do not issue a secret).
  String? _resolveClientSecret() {
    final secret = _config.desktopClientSecret;
    if (secret == null || secret.isEmpty) return null;
    return secret;
  }

  /// Pulls a short, human-readable diagnostic out of a non-2xx token-endpoint
  /// response body.  Falls back to the raw body when it isn't JSON.
  static String _describeError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      final description = json['error_description'];
      if (error != null && description != null) return '$error — $description';
      if (error != null) return error.toString();
    } catch (_) {
      // Not JSON — fall through.
    }
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  Uri _resolveRedirectUri() {
    final raw = _config.desktopRedirectUri;
    if (raw == null || raw.isEmpty) {
      throw const UidsProviderSignInException(
        'Google desktop sign-in requires desktopRedirectUri in '
        'GoogleAuthConfig (e.g. http://localhost:8585/callback).',
      );
    }
    final uri = Uri.parse(raw);
    if (!(uri.host == 'localhost' || uri.host == '127.0.0.1') ||
        uri.scheme != 'http' ||
        uri.port == 0) {
      throw const UidsProviderSignInException(
        'desktopRedirectUri must be a loopback URL with an explicit port '
        '(e.g. http://localhost:8585/callback).',
      );
    }
    return uri;
  }

  List<String> _withOpenIdScopes(List<String> scopes) {
    final set = <String>{...scopes};
    set.addAll(['openid', 'email', 'profile']);
    return set.toList(growable: false);
  }

  String _randomUrlSafe(int byteLength) {
    final rng = Random.secure();
    final bytes = List<int>.generate(
      byteLength,
      (_) => rng.nextInt(256),
      growable: false,
    );
    return _base64UrlNoPad(bytes);
  }

  String _s256Challenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return _base64UrlNoPad(digest.bytes);
  }

  static String _base64UrlNoPad(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // static Future<void> _defaultLaunchUrl(Uri url) async {
  //   final urlStr = url.toString();
  //   if (Platform.isMacOS) {
  //     await Process.run('open', [urlStr]);
  //     return;
  //   }
  //   if (Platform.isWindows) {
  //     // `start` is a cmd builtin; the empty quoted string is the window title.
  //     await Process.run('cmd', ['/c', 'start', '""', urlStr]);
  //     return;
  //   }
  //   if (Platform.isLinux) {
  //     await Process.run('xdg-open', [urlStr]);
  //     return;
  //   }
  //   throw UnsupportedError(
  //     'GoogleDesktopAuthAdapter cannot open a browser on this platform.',
  //   );
  // }
  static Future<void> _defaultLaunchUrl(Uri url) async {
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (launched) {
      return;
    }

    throw UnsupportedError(
      'GoogleDesktopAuthAdapter could not open the browser.',
    );
  }
}
