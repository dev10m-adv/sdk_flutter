import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

const _scopes = <String>['openid', 'email', 'profile'];

/// Web: GIS requires [gsi_web.renderButton]; completes with an OAuth access token or null.
Future<String?> runWebGoogleSignInDialog(BuildContext context) async {
  final completer = Completer<String?>();
  late final StreamSubscription<GoogleSignInAuthenticationEvent> sub;

  sub = GoogleSignIn.instance.authenticationEvents.listen((event) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      try {
        final authz = await event.user.authorizationClient.authorizeScopes(
          _scopes,
        );
        if (!completer.isCompleted) {
          completer.complete(authz.accessToken);
        }
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
      await sub.cancel();
    }
  });

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign in with Google'),
      content: SizedBox(height: 52, width: 240, child: gsi_web.renderButton()),
    ),
  );

  if (!completer.isCompleted) {
    completer.complete(null);
  }
  await sub.cancel();
  return completer.future;
}
