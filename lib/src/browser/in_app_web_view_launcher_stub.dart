import 'package:flutter/widgets.dart' show BuildContext;

import 'auth_browser_launcher.dart';
import 'external_browser_launcher.dart';

/// Web stub for [InAppWebViewLauncher].
///
/// `flutter_inappwebview` has no web implementation, so on the web platform
/// this class transparently delegates every [launch] call to
/// [ExternalBrowserLauncher].  The constructor signature is identical to the
/// IO variant so call-sites remain unchanged across platforms.
final class InAppWebViewLauncher implements AuthBrowserLauncher {
  const InAppWebViewLauncher({
    BuildContext Function()? contextProvider,
    this.dialogWidth = 600,
    this.dialogHeight = 520,
  });

  // ignore: unused_field
  final double dialogWidth;

  // ignore: unused_field
  final double dialogHeight;

  @override
  Future<Uri> launch({
    required Uri authUrl,
    required Uri redirectUri,
    required Duration timeout,
  }) =>
      const ExternalBrowserLauncher().launch(
        authUrl: authUrl,
        redirectUri: redirectUri,
        timeout: timeout,
      );
}
