import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'auth_callback_page.dart';
import '../config/github_auth_config.dart';
import '../errors/uids_auth_exception.dart';
import '../models/auth_provider.dart';
import '../models/provider_auth_result.dart';
import 'provider_auth_adapter.dart';

/// GitHub OAuth 2.0 authentication adapter.
///
/// Implements the Authorization Code flow with PKCE directly — no third-party
/// package required.
///
/// ## Desktop (Windows / macOS / Linux)
/// A transient HTTP loopback server receives the redirect callback.
/// [GitHubAuthConfig.redirectUri] must be a loopback URL with an explicit
/// port and path, e.g. `http://localhost:9100/auth`.
///
/// ## Mobile (Android / iOS)
/// A custom-scheme deep link is used. Register the redirect URI scheme in
/// your `AndroidManifest.xml` / `Info.plist`, then forward every incoming URI
/// to [GitHubAuthAdapter.handleDeepLinkCallback] from your app's link handler
/// (e.g. `app_links` / `uni_links` stream).
///
/// ## Refresh
/// GitHub OAuth App tokens do not expire by default. When a refresh token is
/// present (GitHub Apps with token expiry enabled), [refresh] exchanges it
/// silently. Otherwise the cached access token is returned as-is.
/// Tokens are **never** persisted to disk.
///
/// ## GitHub and OIDC
/// GitHub does not issue an ID token in the OAuth response. The access token
/// is used in place of `idToken` in [ProviderAuthResult].
///
/// ## Thread safety
/// A single adapter instance should not have concurrent [signIn] calls.
final class GitHubAuthAdapter implements ProviderAuthAdapter {
  GitHubAuthAdapter({
    required GitHubAuthConfig config,
    http.Client? httpClient,
  }) : _config = config,
       _http = httpClient ?? http.Client();

  static const _authorizeEndpoint = 'https://github.com/login/oauth/authorize';
  static const _tokenEndpoint = 'https://github.com/login/oauth/access_token';

  static const _desktopFlowTimeout = Duration(minutes: 2);
  static const _mobileFlowTimeout = Duration(minutes: 5);

  final GitHubAuthConfig _config;
  final http.Client _http;

  // ── Static deep-link bridge (mobile) ─────────────────────────────────────

  static final StreamController<Uri> _deepLinkController =
      StreamController<Uri>.broadcast();

  /// Forward deep-link URIs to the adapter on mobile.
  ///
  /// Call this from your app's link handler whenever a URI matching your
  /// GitHub redirect scheme arrives:
  /// ```dart
  /// // e.g. with package:app_links
  /// _appLinks.uriLinkStream.listen(GitHubAuthAdapter.handleDeepLinkCallback);
  /// ```
  static void handleDeepLinkCallback(Uri uri) => _deepLinkController.add(uri);

  // ── In-memory credential cache ────────────────────────────────────────────

  /// Held in memory only — never persisted.
  String? _accessToken;

  /// Present only when GitHub issued a refresh token (token expiry enabled).
  String? _refreshToken;

  // ── Per-flow mutable state ────────────────────────────────────────────────

  HttpServer? _redirectServer;
  StreamSubscription<Uri>? _deepLinkSub;
  Completer<Uri?>? _codeCompleter;
  String? _expectedState;

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ── ProviderAuthAdapter ───────────────────────────────────────────────────

  @override
  AuthProvider get provider => AuthProvider.github;

  @override
  Future<ProviderAuthResult> signIn({List<String> scopes = const []}) async {
    _expectedState = _randomUrlSafe(32);
    final effectiveScopes = _withDefaultScopes(scopes);
    final redirectUri = _resolveRedirectUri();

    // PKCE is used on all platforms — GitHub supports S256.
    final verifier = _randomUrlSafe(64);
    final challenge = _s256Challenge(verifier);

    try {
      if (_isMobile) {
        await _setupDeepLinkListener();
      } else {
        await _setupLoopbackServer(redirectUri);
      }

      final authUrl = Uri.parse(_authorizeEndpoint).replace(
        queryParameters: <String, String>{
          'client_id': _config.clientId,
          'redirect_uri': redirectUri,
          'scope': effectiveScopes.join(' '),
          'state': _expectedState!,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
        },
      );

      if (!await launcher.canLaunchUrl(authUrl)) {
        throw const UidsProviderSignInException(
          'Could not open the system browser for GitHub sign-in.',
        );
      }
      await launcher.launchUrl(
        authUrl,
        mode: launcher.LaunchMode.externalApplication,
      );

      final callbackUri = await _waitForCallback();
      if (callbackUri == null) {
        throw const UidsProviderCancelledException(
          'GitHub sign-in timed out or was cancelled.',
        );
      }

      return await _exchangeCode(
        callbackUri: callbackUri,
        redirectUri: redirectUri,
        scopes: effectiveScopes,
        verifier: verifier,
      );
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException('GitHub sign-in failed.', cause: e);
    } finally {
      await _cleanup();
    }
  }

  @override
  Future<ProviderAuthResult> refresh({List<String> scopes = const []}) async {
    final refreshToken = _refreshToken;
    if (refreshToken != null) {
      return _refreshWithToken(refreshToken, scopes);
    }

    // GitHub OAuth App tokens do not expire by default — return cached token.
    final cached = _accessToken;
    if (cached != null) {
      return ProviderAuthResult(
        provider: AuthProvider.github,
        idToken: cached,
        accessToken: cached,
        scopes: _withDefaultScopes(scopes),
      );
    }

    throw const UidsProviderSignInException(
      'No cached GitHub credential — interactive sign-in required.',
    );
  }

  @override
  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
  }

  // ── Token exchange ────────────────────────────────────────────────────────

  Future<ProviderAuthResult> _exchangeCode({
    required Uri callbackUri,
    required String redirectUri,
    required List<String> scopes,
    required String verifier,
  }) async {
    _validateCallbackUri(callbackUri);
    final code = callbackUri.queryParameters['code']!;

    final response = await _http.post(
      Uri.parse(_tokenEndpoint),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'client_id': _config.clientId,
        'client_secret': _config.clientSecret,
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
      },
    );

    if (response.statusCode != 200) {
      throw UidsProviderSignInException(
        'GitHub token exchange failed (HTTP ${response.statusCode}): '
        '${_describeError(response.body)}',
      );
    }

    return _buildResult(
      jsonDecode(response.body) as Map<String, dynamic>,
      scopes,
    );
  }

  Future<ProviderAuthResult> _refreshWithToken(
    String token,
    List<String> scopes,
  ) async {
    final effectiveScopes = _withDefaultScopes(scopes);
    try {
      final response = await _http.post(
        Uri.parse(_tokenEndpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: <String, String>{
          'client_id': _config.clientId,
          'client_secret': _config.clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': token,
        },
      );

      if (response.statusCode != 200) {
        _refreshToken = null;
        throw UidsProviderSignInException(
          'GitHub token refresh failed (HTTP ${response.statusCode}): '
          '${_describeError(response.body)}',
        );
      }

      return _buildResult(
        jsonDecode(response.body) as Map<String, dynamic>,
        effectiveScopes,
      );
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException(
        'GitHub silent refresh failed.',
        cause: e,
      );
    }
  }

  ProviderAuthResult _buildResult(
    Map<String, dynamic> data,
    List<String> requestedScopes,
  ) {
    final error = data['error'] as String?;
    if (error != null) {
      final desc = data['error_description'] as String? ?? '';
      if (error == 'access_denied') throw const UidsProviderCancelledException();
      throw UidsProviderSignInException('GitHub OAuth error: $error — $desc');
    }

    final accessToken = data['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const UidsProviderSignInException(
        'GitHub token response is missing access_token.',
      );
    }

    _accessToken = accessToken;

    final newRefreshToken = data['refresh_token'] as String?;
    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      _refreshToken = newRefreshToken;
    }

    // GitHub returns scopes comma-separated in the JSON response.
    final scopeStr = (data['scope'] as String? ?? '').trim();
    final grantedScopes = scopeStr.isEmpty
        ? requestedScopes
        : scopeStr.split(RegExp(r'[, ]+'));

    return ProviderAuthResult(
      provider: AuthProvider.github,
      // GitHub OAuth does not issue an OIDC id_token; access_token is used instead.
      idToken: accessToken,
      accessToken: accessToken,
      scopes: grantedScopes,
    );
  }

  // ── Desktop: HTTP loopback server ─────────────────────────────────────────

  Future<void> _setupLoopbackServer(String redirectUriStr) async {
    final redirectUri = Uri.parse(redirectUriStr);
    _codeCompleter = Completer<Uri?>();

    _redirectServer = await HttpServer.bind(
      'localhost',
      redirectUri.port,
      shared: true,
    );

    final expectedPath = redirectUri.path.isEmpty ? '/' : redirectUri.path;

    _redirectServer!.listen((HttpRequest request) async {
      final uri = request.uri;

      if (uri.path != expectedPath) {
        await _writeBrowserResponse(
          request,
          status: HttpStatus.notFound,
          title: 'Not Found',
          message: 'Unknown callback path.',
          isSuccess: false,
        );
        return;
      }

      if (uri.queryParameters['state'] != _expectedState) {
        await _writeBrowserResponse(
          request,
          status: HttpStatus.badRequest,
          title: 'Sign-in Failed',
          message: 'State mismatch — possible CSRF attempt.',
          isSuccess: false,
        );
        if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
          _codeCompleter!.completeError(
            const UidsProviderSignInException('Invalid OAuth state.'),
          );
        }
        return;
      }

      final error = uri.queryParameters['error'];
      if (error != null) {
        final desc = uri.queryParameters['error_description'] ?? '';
        await _writeBrowserResponse(
          request,
          status: HttpStatus.badRequest,
          title: 'Sign-in Failed',
          message: 'GitHub returned an error: $error — $desc',
          isSuccess: false,
        );
        if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
          final ex = error == 'access_denied'
              ? const UidsProviderCancelledException()
              : UidsProviderSignInException('GitHub OAuth error: $error — $desc');
          _codeCompleter!.completeError(ex);
        }
        return;
      }

      await _writeBrowserResponse(
        request,
        status: HttpStatus.ok,
        title: 'GitHub Sign-In Complete',
        message:
            'Authentication successful! You may close this tab and return to the app.',
      );

      await _redirectServer?.close();
      _redirectServer = null;

      if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
        _codeCompleter!.complete(uri);
      }
    });
  }

  Future<void> _writeBrowserResponse(
    HttpRequest request, {
    required int status,
    required String title,
    required String message,
    bool isSuccess = true,
  }) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(
        buildAuthCallbackHtml(
          title: title,
          message: message,
          isSuccess: isSuccess,
        ),
      );
    return request.response.close();
  }

  // ── Mobile: deep-link listener ────────────────────────────────────────────

  Future<void> _setupDeepLinkListener() async {
    _codeCompleter = Completer<Uri?>();
    _deepLinkSub = _deepLinkController.stream.listen(_handleDeepLinkUri);
  }

  void _handleDeepLinkUri(Uri uri) {
    if (_codeCompleter == null || _codeCompleter!.isCompleted) return;

    final error = uri.queryParameters['error'];
    if (error != null) {
      final desc = uri.queryParameters['error_description'] ?? '';
      final ex = error == 'access_denied'
          ? const UidsProviderCancelledException()
          : UidsProviderSignInException('GitHub OAuth error: $error — $desc');
      _codeCompleter!.completeError(ex);
      return;
    }

    if (uri.queryParameters['state'] != _expectedState) {
      _codeCompleter!.completeError(
        const UidsProviderSignInException(
          'Invalid OAuth state in deep-link callback.',
        ),
      );
      return;
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      _codeCompleter!.completeError(
        const UidsProviderSignInException(
          'No authorization code in deep-link callback.',
        ),
      );
      return;
    }

    _codeCompleter!.complete(uri);
  }

  // ── Callback wait ─────────────────────────────────────────────────────────

  Future<Uri?> _waitForCallback() async {
    final timeout = _isMobile ? _mobileFlowTimeout : _desktopFlowTimeout;
    return _codeCompleter!.future.timeout(timeout, onTimeout: () => null);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> _cleanup() async {
    await _redirectServer?.close(force: true);
    _redirectServer = null;
    await _deepLinkSub?.cancel();
    _deepLinkSub = null;
    _codeCompleter = null;
    _expectedState = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _validateCallbackUri(Uri uri) {
    final error = uri.queryParameters['error'];
    if (error != null) {
      final desc = uri.queryParameters['error_description'] ?? '';
      if (error == 'access_denied') throw const UidsProviderCancelledException();
      throw UidsProviderSignInException('GitHub OAuth error: $error — $desc');
    }
    if (!uri.queryParameters.containsKey('code')) {
      throw const UidsProviderSignInException(
        'GitHub callback is missing the authorization code.',
      );
    }
  }

  List<String> _withDefaultScopes(List<String> scopes) {
    return <String>{
      'read:user',
      'user:email',
      ...scopes,
    }.toList(growable: false);
  }

  String _resolveRedirectUri() {
    final uri = _config.redirectUri;
    if (uri == null || uri.isEmpty) {
      throw const UidsProviderSignInException(
        'GitHubAuthConfig.redirectUri is required.\n'
        '  Desktop: use a loopback URL, e.g. http://localhost:9100/auth\n'
        '  Mobile:  use a custom scheme, e.g. com.example.app://auth/github',
      );
    }
    return uri;
  }

  static String _describeError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      final description = json['error_description'];
      if (error != null && description != null) return '$error — $description';
      if (error != null) return error.toString();
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
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
}
