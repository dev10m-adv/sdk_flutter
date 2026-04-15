import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:uids_io_sdk_flutter/src/sdk_log.dart';

class AuthLogout extends StatelessWidget {
  const AuthLogout({super.key});
  
  static Future<void> logout(BuildContext context) async {
    final FlutterSecureStorage secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: "Entities_List");
    await secureStorage.delete(key: "JWT_Token");
    await secureStorage.delete(key: "Username");
    await secureStorage.delete(key: "DatabaseName");
    sdkLogInfo('auth', 'user logged out, storage cleared');
    if (context.mounted) {
      context.goNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.logout),
      onPressed: () => logout(context),
    );
  }
}
