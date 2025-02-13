import 'package:flutter/material.dart';
import 'package:uids_io_sdk_flutter/auth_view.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SignInPage(),
    );
  }
}

class SignInPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AuthScreen(key: globalKey);///// this is how you call login screen
  }
}