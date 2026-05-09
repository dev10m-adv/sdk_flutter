import 'package:flutter/material.dart';
import 'package:uids_io_sdk_flutter/uids_io_sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = UidsSdkConfig(
      apiBaseUrl: Uri.parse('https://api.example.com'),
      authBaseUrl: Uri.parse('https://auth.example.com'),
      clientId: 'backend-client-id',
      google: const GoogleAuthConfig(webClientId: 'google-web-client-id'),
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('UIDS Auth SDK Example')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Create an SDK instance with UidsAuthSdk.create() and initialize '
            'it with ${config.clientId}.',
          ),
        ),
      ),
    );
  }
}
