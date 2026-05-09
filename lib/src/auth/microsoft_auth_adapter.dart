import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uids_io_sdk_flutter/src/auth/auth_callback_page.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import '../config/microsoft_auth_config.dart';
import '../errors/uids_auth_exception.dart';
import '../models/auth_provider.dart';
import '../models/provider_auth_result.dart';
import 'provider_auth_adapter.dart';

/// Microsoft (Entra ID / Azure AD) authentication adapter.
///
/// Implements the OAuth 2.0 Authorization Code flow directly — no MSAL or
/// third-party package required.
///
/// ## Desktop (Windows / macOS / Linux)
/// A transient HTTP loopback server receives the redirect callback.
/// [MicrosoftAuthConfig.redirectUri] must be a loopback URL with an explicit
/// port and path, e.g. `http://localhost:9000/auth`.
///
/// ## Mobile (Android / iOS)
/// A custom-scheme deep link is used.  Register the redirect URI scheme in
/// your `AndroidManifest.xml` / `Info.plist`, then forward every incoming URI
/// to [MicrosoftAuthAdapter.handleDeepLinkCallback] from your app's link
/// handler (e.g. `app_links` / `uni_links` stream).
///
/// ## Refresh
/// After a successful [signIn] the Microsoft refresh token is stored
/// in-memory so that [refresh] can silently obtain new tokens without UI.
/// The token is **never** persisted to disk.
///
/// ## Thread safety
/// A single adapter instance should not have concurrent [signIn] calls.
final class MicrosoftAuthAdapter implements ProviderAuthAdapter {
  MicrosoftAuthAdapter({
    required MicrosoftAuthConfig config,
    http.Client? httpClient,
  }) : _config = config,
       _http = httpClient ?? http.Client();

  static const _authorizeBase =
      'https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize';
  static const _tokenBase =
      'https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token';

  static const _desktopFlowTimeout = Duration(minutes: 2);
  static const _mobileFlowTimeout = Duration(minutes: 5);

  final MicrosoftAuthConfig _config;
  final http.Client _http;

  // ── Static deep-link bridge (mobile) ─────────────────────────────────────

  static final StreamController<Uri> _deepLinkController =
      StreamController<Uri>.broadcast();

  /// Forward deep-link URIs to the adapter on mobile.
  ///
  /// Call this from your app's link handler whenever a URI matching your
  /// Microsoft redirect scheme arrives:
  /// ```dart
  /// // e.g. with package:app_links
  /// _appLinks.uriLinkStream.listen(MicrosoftAuthAdapter.handleDeepLinkCallback);
  /// ```
  static void handleDeepLinkCallback(Uri uri) => _deepLinkController.add(uri);

  // ── In-memory credential cache ────────────────────────────────────────────

  /// Held in memory only — never persisted.  Set after a successful [signIn]
  /// so that [refresh] can run without showing UI.
  String? _refreshToken;

  // ── Per-flow mutable state ────────────────────────────────────────────────

  HttpServer? _redirectServer;
  StreamSubscription<Uri>? _deepLinkSub;
  Completer<Uri?>? _codeCompleter;
  String? _expectedState;
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ── ProviderAuthAdapter ───────────────────────────────────────────────────

  @override
  AuthProvider get provider => AuthProvider.microsoft;

  @override
  Future<ProviderAuthResult> signIn({List<String> scopes = const []}) async {
    _expectedState = DateTime.now().millisecondsSinceEpoch.toString();
    final effectiveScopes = _withRequiredScopes(scopes);
    final redirectUri = _resolveRedirectUri();
    final tenant = _config.tenantId;

    try {
      if (_isMobile) {
        await _setupDeepLinkListener();
      } else {
        await _setupLoopbackServer(redirectUri);
      }

      final authUrl = Uri.parse(_authorizeBase.replaceFirst('{tenant}', tenant))
          .replace(
            queryParameters: <String, String>{
              'client_id': _config.clientId,
              'response_type': 'code',
              'redirect_uri': redirectUri,
              'response_mode': 'query',
              'scope': effectiveScopes.join(' '),
              'state': _expectedState!,
              'prompt': 'select_account',
            },
          );

      if (!await launcher.canLaunchUrl(authUrl)) {
        throw const UidsProviderSignInException(
          'Could not open the system browser for Microsoft sign-in.',
        );
      }
      await launcher.launchUrl(
        authUrl,
        mode: launcher.LaunchMode.externalApplication,
      );

      final callbackUri = await _waitForCallback();
      if (callbackUri == null) {
        throw const UidsProviderCancelledException(
          'Microsoft sign-in timed out or was cancelled.',
        );
      }

      return await _exchangeCode(
        callbackUri: callbackUri,
        redirectUri: redirectUri,
        tenant: tenant,
        scopes: effectiveScopes,
      );
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException('Microsoft sign-in failed.', cause: e);
    } finally {
      await _cleanup();
    }
  }

  @override
  Future<ProviderAuthResult> refresh({List<String> scopes = const []}) async {
    final token = _refreshToken;
    if (token == null) {
      throw const UidsProviderSignInException(
        'No cached Microsoft refresh token — interactive sign-in required.',
      );
    }

    final effectiveScopes = _withRequiredScopes(scopes);
    final tenant = _config.tenantId;
    final redirectUri = _resolveRedirectUri();

    try {
      final response = await _http.post(
        Uri.parse(_tokenBase.replaceFirst('{tenant}', tenant)),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: <String, String>{
          'client_id': _config.clientId,
          'grant_type': 'refresh_token',
          'refresh_token': token,
          'redirect_uri': redirectUri,
          'scope': effectiveScopes.join(' '),
        },
      );

      if (response.statusCode != 200) {
        _refreshToken = null;
        throw UidsProviderSignInException(
          'Microsoft token refresh failed (HTTP ${response.statusCode}): '
          '${_describeError(response.body)}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _buildResult(data, effectiveScopes);
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException(
        'Microsoft silent refresh failed.',
        cause: e,
      );
    }
  }

  @override
  Future<void> signOut() async {
    _refreshToken = null;
  }

  // ── Token exchange ────────────────────────────────────────────────────────

  Future<ProviderAuthResult> _exchangeCode({
    required Uri callbackUri,
    required String redirectUri,
    required String tenant,
    required List<String> scopes,
  }) async {
    _validateCallbackUri(callbackUri);
    final code = callbackUri.queryParameters['code']!;

    final response = await _http.post(
      Uri.parse(_tokenBase.replaceFirst('{tenant}', tenant)),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: <String, String>{
        'client_id': _config.clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'scope': scopes.join(' '),
      },
    );

    if (response.statusCode != 200) {
      throw UidsProviderSignInException(
        'Microsoft token exchange failed (HTTP ${response.statusCode}): '
        '${_describeError(response.body)}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _buildResult(data, scopes);
  }

  ProviderAuthResult _buildResult(
    Map<String, dynamic> data,
    List<String> requestedScopes,
  ) {
    final accessToken = data['access_token'] as String?;
    final idToken = data['id_token'] as String?;
    final newRefreshToken = data['refresh_token'] as String?;
    final grantedScopeStr = (data['scope'] as String? ?? '').trim();
    final grantedScopes = grantedScopeStr.isEmpty
        ? requestedScopes
        : grantedScopeStr.split(' ');

    if (accessToken == null || accessToken.isEmpty) {
      throw const UidsProviderSignInException(
        'Microsoft token response is missing access_token.',
      );
    }

    // Rotate the cached refresh token when a new one is issued.
    if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
      _refreshToken = newRefreshToken;
    }

    return ProviderAuthResult(
      provider: AuthProvider.microsoft,
      // id_token is returned when openid scope is granted (always included
      // by _withRequiredScopes).  Fall back to access_token as a last resort.
      idToken: idToken ?? accessToken,
      accessToken: accessToken,
      scopes: grantedScopes,
    );
  }

  // ── Desktop: HTTP loopback server ─────────────────────────────────────────

  Future<void> _setupLoopbackServer(String redirectUriStr) async {
    final redirectUri = Uri.parse(redirectUriStr);
    _codeCompleter = Completer<Uri?>();

    _redirectServer = await HttpServer.bind(
      // InternetAddress.loopbackIPv4,
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
          message: 'Microsoft returned an error: $error — $desc',
          isSuccess: false,
        );
        if (_codeCompleter != null && !_codeCompleter!.isCompleted) {
          final ex = error == 'access_denied'
              ? const UidsProviderCancelledException()
              : UidsProviderSignInException(
                  'Microsoft OAuth error: $error — $desc',
                );
          _codeCompleter!.completeError(ex);
        }
        return;
      }

      await _writeBrowserResponse(
        request,
        status: HttpStatus.ok,
        title: 'Microsoft Sign-In Complete',
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
          : UidsProviderSignInException(
              'Microsoft OAuth error: $error — $desc',
            );
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
      if (error == 'access_denied')
        throw const UidsProviderCancelledException();
      throw UidsProviderSignInException(
        'Microsoft OAuth error: $error — $desc',
      );
    }
    if (!uri.queryParameters.containsKey('code')) {
      throw const UidsProviderSignInException(
        'Microsoft callback is missing the authorization code.',
      );
    }
  }

  /// Always includes the scopes that are required for [refresh] and a valid
  /// id_token.
  List<String> _withRequiredScopes(List<String> scopes) {
    return <String>{
      'openid',
      'profile',
      'email',
      'offline_access', // required to receive a refresh_token from Entra
      ...scopes,
    }.toList(growable: false);
  }

  String _resolveRedirectUri() {
    final uri = _config.redirectUri;
    if (uri == null || uri.isEmpty) {
      throw const UidsProviderSignInException(
        'MicrosoftAuthConfig.redirectUri is required.\n'
        '  Desktop: use a loopback URL, e.g. http://localhost:9000/auth\n'
        '  Mobile:  use a custom scheme, e.g. msauth://com.example.app/callback',
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
}
