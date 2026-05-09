import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../errors/uids_auth_exception.dart';
import 'auth_browser_launcher.dart';
import 'external_browser_launcher.dart';

/// In-app WebView launcher for native platforms (Android / iOS / macOS / Windows).
///
/// On **Linux**, `flutter_inappwebview` is not supported.  [launch] detects
/// this at runtime and transparently delegates to [ExternalBrowserLauncher]
/// so the OAuth flow still works — no code changes required on the call-site.
///
/// On all other native platforms the launcher shows a modal dialog containing
/// a full [InAppWebView].  The WebView intercepts the redirect to [redirectUri]
/// via [InAppWebView.shouldOverrideUrlLoading] before any OS URI handler fires,
/// closes the dialog, and resolves the future with the raw callback [Uri].
///
/// See [InAppWebViewLauncher] (the public class re-exported by
/// `in_app_web_view_launcher.dart`) for usage examples.
final class InAppWebViewLauncher implements AuthBrowserLauncher {
  const InAppWebViewLauncher({
    BuildContext Function()? contextProvider,
    this.dialogWidth = 600,
    this.dialogHeight = 520,
  }) : _contextProvider = contextProvider;

  final BuildContext Function()? _contextProvider;

  /// Maximum width of the WebView dialog, in logical pixels.
  final double dialogWidth;

  /// Height of the WebView pane inside the dialog, in logical pixels.
  final double dialogHeight;

  // ── AuthBrowserLauncher ───────────────────────────────────────────────────

  @override
  Future<Uri> launch({
    required Uri authUrl,
    required Uri redirectUri,
    required Duration timeout,
  }) async {
    // flutter_inappwebview has no Linux implementation — fall back to the
    // system browser so the auth flow still works on Linux desktops.
    if (Platform.isLinux) {
      return const ExternalBrowserLauncher().launch(
        authUrl: authUrl,
        redirectUri: redirectUri,
        timeout: timeout,
      );
    }

    final contextProvider = _contextProvider;
    if (contextProvider == null) {
      throw const UidsProviderSignInException(
        'InAppWebViewLauncher requires a contextProvider on this platform. '
        'Pass contextProvider: () => navigatorKey.currentContext! when '
        'constructing InAppWebViewLauncher.',
      );
    }

    final context = contextProvider();
    if (!context.mounted) {
      throw const UidsProviderSignInException(
        'InAppWebViewLauncher: the provided BuildContext is not mounted. '
        'Ensure contextProvider returns a currently active context.',
      );
    }

    final completer = Completer<Uri>();

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => _AuthWebViewDialog(
          authUrl: authUrl,
          redirectUri: redirectUri,
          timeout: timeout,
          onComplete: (uri) {
            if (!completer.isCompleted) completer.complete(uri);
          },
          onCancel: () {
            if (!completer.isCompleted) {
              completer.completeError(const UidsProviderCancelledException());
            }
          },
          dialogWidth: dialogWidth,
          dialogHeight: dialogHeight,
        ),
      ).then((_) {
        if (!completer.isCompleted) {
          completer.completeError(const UidsProviderCancelledException());
        }
      }),
    );

    try {
      return await completer.future;
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsProviderSignInException(
        'In-app WebView authentication failed.',
        cause: e,
      );
    }
  }
}

// ── Internal dialog widget ────────────────────────────────────────────────────

class _AuthWebViewDialog extends StatefulWidget {
  const _AuthWebViewDialog({
    required this.authUrl,
    required this.redirectUri,
    required this.timeout,
    required this.onComplete,
    required this.onCancel,
    required this.dialogWidth,
    required this.dialogHeight,
  });

  final Uri authUrl;
  final Uri redirectUri;
  final Duration timeout;
  final void Function(Uri) onComplete;
  final VoidCallback onCancel;
  final double dialogWidth;
  final double dialogHeight;

  @override
  State<_AuthWebViewDialog> createState() => _AuthWebViewDialogState();
}

class _AuthWebViewDialogState extends State<_AuthWebViewDialog> {
  Timer? _timer;
  bool _done = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.timeout, _handleTimeout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  void _handleTimeout() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    widget.onCancel();
  }

  void _handleCancel() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    Navigator.of(context, rootNavigator: true).pop();
    widget.onCancel();
  }

  void _handleRedirect(Uri callbackUri) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    Navigator.of(context, rootNavigator: true).pop();
    widget.onComplete(callbackUri);
  }

  // ── Redirect detection ────────────────────────────────────────────────────

  bool _isRedirectUri(WebUri? webUri) {
    if (webUri == null) return false;
    final uriStr = webUri.toString();
    final baseStr = widget.redirectUri.toString();
    if (!uriStr.startsWith(baseStr)) return false;
    if (uriStr.length > baseStr.length) {
      final next = uriStr[baseStr.length];
      if (next != '?' && next != '#' && next != '/') return false;
    }
    return true;
  }

  Uri _toCallbackUri(WebUri webUri) => Uri.parse(webUri.toString());

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.dialogWidth),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              SizedBox(
                height: widget.dialogHeight,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri(widget.authUrl.toString()),
                        ),
                        initialSettings: InAppWebViewSettings(
                          useShouldOverrideUrlLoading: true,
                          mediaPlaybackRequiresUserGesture: false,
                          allowsInlineMediaPlayback: true,
                        ),
                        shouldOverrideUrlLoading:
                            (controller, navigationAction) async {
                          final url = navigationAction.request.url;
                          if (_isRedirectUri(url)) {
                            _handleRedirect(_toCallbackUri(url!));
                            return NavigationActionPolicy.CANCEL;
                          }
                          return NavigationActionPolicy.ALLOW;
                        },
                        onLoadStart: (controller, url) {
                          if (_isRedirectUri(url)) {
                            _handleRedirect(_toCallbackUri(url!));
                          } else if (mounted) {
                            setState(() => _isLoading = true);
                          }
                        },
                        onLoadStop: (controller, url) {
                          if (mounted) setState(() => _isLoading = false);
                        },
                        onReceivedError: (controller, request, error) {
                          if (_isRedirectUri(request.url)) return;
                          if (mounted) setState(() => _isLoading = false);
                        },
                      ),
                    ),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Sign in',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
            tooltip: 'Cancel',
            onPressed: _handleCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
