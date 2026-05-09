import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../auth/auth_callback_page.dart';
import '../errors/uids_auth_exception.dart';
import 'auth_browser_launcher.dart';

/// Launches OAuth authentication in the system browser (default behavior).
///
/// ## Desktop (Windows / macOS / Linux)
/// Binds a transient HTTP loopback server on the port specified in
/// [redirectUri] to capture the callback.  The system browser is opened at
/// [authUrl]; when the provider redirects back to [redirectUri] the loopback
/// server intercepts the request, serves a small HTML page, and resolves the
/// [launch] future with the callback [Uri].
///
/// ## Mobile (Android / iOS)
/// Registers a listener on a shared deep-link stream, then opens [authUrl] in
/// the external browser.  Your app must forward incoming deep-link URIs to
/// [ExternalBrowserLauncher.handleDeepLinkCallback] from your link-handler
/// (e.g. `app_links` / `uni_links` stream):
///
/// ```dart
/// _appLinks.uriLinkStream.listen(ExternalBrowserLauncher.handleDeepLinkCallback);
/// ```
///
/// Backward-compatible delegates are kept on the individual adapters:
/// `MicrosoftAuthAdapter.handleDeepLinkCallback` and
/// `GitHubAuthAdapter.handleDeepLinkCallback` both forward here.
final class ExternalBrowserLauncher implements AuthBrowserLauncher {
  const ExternalBrowserLauncher();

  // ── Static deep-link bridge ───────────────────────────────────────────────

  static final StreamController<Uri> _deepLinkController =
      StreamController<Uri>.broadcast();

  /// Forward deep-link URIs from your app's link handler to the active OAuth
  /// flow on mobile.
  ///
  /// Call this from your link-handler stream whenever a URI matching your
  /// OAuth redirect scheme arrives:
  /// ```dart
  /// _appLinks.uriLinkStream.listen(ExternalBrowserLauncher.handleDeepLinkCallback);
  /// ```
  static void handleDeepLinkCallback(Uri uri) => _deepLinkController.add(uri);

  // ── AuthBrowserLauncher ───────────────────────────────────────────────────

  @override
  Future<Uri> launch({
    required Uri authUrl,
    required Uri redirectUri,
    required Duration timeout,
  }) {
    if (_isMobile) {
      return _launchMobile(
        authUrl: authUrl,
        redirectUri: redirectUri,
        timeout: timeout,
      );
    }
    return _launchDesktop(
      authUrl: authUrl,
      redirectUri: redirectUri,
      timeout: timeout,
    );
  }

  // ── Desktop: HTTP loopback server ─────────────────────────────────────────

  Future<Uri> _launchDesktop({
    required Uri authUrl,
    required Uri redirectUri,
    required Duration timeout,
  }) async {
    final expectedPath = redirectUri.path.isEmpty ? '/' : redirectUri.path;
    final completer = Completer<Uri>();

    HttpServer? server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        redirectUri.port,
        shared: true,
      );

      server.listen(
        (HttpRequest request) async {
          final uri = request.uri;

          if (uri.path != expectedPath) {
            _writeHtmlResponse(
              request,
              status: HttpStatus.notFound,
              message: 'Unknown callback path.',
              isSuccess: false,
            );
            return;
          }

          // Close the server before completing — we only need one callback.
          await server?.close();
          server = null;

          final error = uri.queryParameters['error'];
          if (error != null) {
            _writeHtmlResponse(
              request,
              status: HttpStatus.badRequest,
              message: 'Sign-in was rejected by the provider: $error',
              isSuccess: false,
            );
          } else {
            _writeHtmlResponse(
              request,
              status: HttpStatus.ok,
              message:
                  'Authentication complete. You may close this tab and return to the app.',
              isSuccess: true,
            );
          }

          if (!completer.isCompleted) {
            completer.complete(
              redirectUri.replace(queryParameters: uri.queryParameters),
            );
          }
        },
        onError: (Object e) {
          if (!completer.isCompleted) {
            completer.completeError(
              UidsProviderSignInException(
                'Loopback server error during authentication.',
                cause: e,
              ),
            );
          }
        },
      );

      final launched = await launcher.launchUrl(
        authUrl,
        mode: launcher.LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const UidsProviderSignInException(
          'Could not open the system browser for authentication.',
        );
      }

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw const UidsProviderSignInException(
            'Authentication timed out — the browser callback never arrived.',
          );
        },
      );
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException(
        'Browser authentication failed.',
        cause: e,
      );
    } finally {
      await server?.close(force: true);
    }
  }

  // ── Mobile: deep-link listener ────────────────────────────────────────────

  Future<Uri> _launchMobile({
    required Uri authUrl,
    required Uri redirectUri,
    required Duration timeout,
  }) async {
    final completer = Completer<Uri>();
    StreamSubscription<Uri>? sub;

    try {
      sub = _deepLinkController.stream.listen((uri) {
        if (!completer.isCompleted) completer.complete(uri);
      });

      final launched = await launcher.launchUrl(
        authUrl,
        mode: launcher.LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const UidsProviderSignInException(
          'Could not open the browser for authentication.',
        );
      }

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw const UidsProviderSignInException(
            'Authentication timed out — no deep-link callback was received.',
          );
        },
      );
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException(
        'Mobile browser authentication failed.',
        cause: e,
      );
    } finally {
      await sub?.cancel();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void _writeHtmlResponse(
    HttpRequest request, {
    required int status,
    required String message,
    required bool isSuccess,
  }) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..write(
        buildAuthCallbackHtml(
          title: isSuccess
              ? 'Authentication Complete'
              : 'Authentication Failed',
          message: message,
          isSuccess: isSuccess,
        ),
      );
    request.response.close();
  }
}
