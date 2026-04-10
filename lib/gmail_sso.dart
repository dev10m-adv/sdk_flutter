import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';
import 'package:uids_io_sdk_flutter/models/aud_model.dart';
import 'package:uids_io_sdk_flutter/models/auth_response_model.dart';
import 'package:uids_io_sdk_flutter/models/auth_token_model.dart';
import 'package:uids_io_sdk_flutter/models/azure_token_input_model.dart';

import 'gmail_sso_web_stub.dart'
    if (dart.library.html) 'gmail_sso_web_impl.dart'
    as gmail_web;

const _googleScopes = <String>['openid', 'email', 'profile'];

class GmailSSO {
  static final Dio _dio = Dio();
  static final Dio dio2 = Dio();

  String? clientId_shared_preferences;
  String? idpName_shared_preferences;
  String? deviceId_shared_preferences;
  String? redirect_uri_shared_preferences;

  bool _gmailConfigLoaded = false;
  bool _googlePluginInitialized = false;

  Future<void> _loadGmailConfiguration() async {
    if (_gmailConfigLoaded) return;

    final FlutterSecureStorage secureStorage = FlutterSecureStorage();
    final confString = await secureStorage.read(key: 'Configurations');
    if (confString == null || confString.isEmpty) {
      _gmailConfigLoaded = true;
      return;
    }

    final List<dynamic> conf = jsonDecode(confString) as List<dynamic>;
    Map<String, dynamic> map = <String, dynamic>{};
    for (final dynamic item in conf) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        final idpName = m['idp_name'] ?? m['idpname'];
        if (idpName == 'Gmail') {
          map = m;
          break;
        }
      }
    }

    if (map.isNotEmpty) {
      final clientConfig =
          map['app_idp_client_configuration'] ?? map['appidpclientconfiguration'];
      if (clientConfig is Map) {
        final Map<String, dynamic> cc = Map<String, dynamic>.from(clientConfig);
        clientId_shared_preferences = cc['CLIENT_ID'] as String? ?? '';
        redirect_uri_shared_preferences = cc['REDIRECT_URI'] as String? ?? '';
      }
      idpName_shared_preferences = map['idpname'] as String?;
      deviceId_shared_preferences = await secureStorage.read(key: 'DeviceId');
    }
    _gmailConfigLoaded = true;
  }

  Future<void> _configureGoogleSignInPluginIfNeeded() async {
    if (_googlePluginInitialized) return;
    await _loadGmailConfiguration();

    final String cid = clientId_shared_preferences ?? '';
    if (cid.isEmpty) return;

    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(clientId: cid);
    } else if (Platform.isAndroid || Platform.isIOS) {
      await GoogleSignIn.instance.initialize(serverClientId: cid);
    }
    _googlePluginInitialized = true;
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    await _loadGmailConfiguration();

    if (kIsWeb) {
      await _configureGoogleSignInPluginIfNeeded();
      await _signInWithGoogleWeb(context);
    } else if (Platform.isAndroid || Platform.isIOS) {
      await _configureGoogleSignInPluginIfNeeded();
      await _signInWithGoogleMobile(context);
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await _signInWithGoogleDesktop(context);
    }
  }

  Future<void> _signInWithGoogleWeb(BuildContext context) async {
    try {
      final String? token = await gmail_web.runWebGoogleSignInDialog(context);
      if (token != null && context.mounted) {
        await sendToBackend(token, context);
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
    }
  }

  Future<void> _signInWithGoogleMobile(BuildContext context) async {
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate(scopeHint: _googleScopes);
      final GoogleSignInClientAuthorization authz = await account
          .authorizationClient
          .authorizeScopes(_googleScopes);
      if (!context.mounted) return;
      await sendToBackend(authz.accessToken, context);
    } on GoogleSignInException catch (e) {
      debugPrint('Error during Google Sign-In: $e');
    }
  }

  Future<void> _signInWithGoogleDesktop(BuildContext context) async {
    try {
      final String clientId = clientId_shared_preferences ?? '';
      final String redirectUri = redirect_uri_shared_preferences ?? '';
      const String authorizationEndpoint =
          'https://accounts.google.com/o/oauth2/auth';
      const String scope = 'openid email profile';

      final String authUrl =
          '$authorizationEndpoint?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&scope=$scope&prompt=select_account';

      _showOAuthDialog(context, authUrl);
    } catch (e) {
      debugPrint('Error during OAuth on Desktop with InAppWebView: $e');
    }
  }

  void _showOAuthDialog(BuildContext context, String authUrl) {
    bool isPopupVisible = true;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Visibility(
                  visible: isPopupVisible,
                  child: Container(
                    width: double.maxFinite,
                    height: 500,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(authUrl)),
                      onLoadStart: (controller, url) {},
                      onLoadStop: (controller, url) {
                        if (url != null &&
                            url.toString().startsWith(
                              redirect_uri_shared_preferences ?? '',
                            )) {
                          _handleOAuthResponse(controller, url, context, () {
                            setState(() {
                              isPopupVisible = false;
                            });
                          });
                        } else {
                          debugPrint('Intermediate page loaded');
                        }
                      },
                      onReceivedError: (controller, request, error) {
                        debugPrint(
                          'Error loading: ${request.url}, ${error.description}',
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleOAuthResponse(
    InAppWebViewController controller,
    Uri? url,
    BuildContext context,
    VoidCallback onClosePopup,
  ) async {
    try {
      final String? scriptResult = await controller.evaluateJavascript(
        source: '''
      (function() {
        return JSON.stringify(document.body.innerText);
      })();
    ''',
      );

      if (scriptResult != null) {
        final String sanitizedValue = scriptResult
            .replaceAll(r'\"', '"')
            .replaceAll(RegExp(r'^"|"$'), '');
        final dynamic decodedJson = json.decode(sanitizedValue);

        if (decodedJson is Map<String, dynamic> &&
            decodedJson.containsKey('access_token')) {
          onClosePopup();

          await sendToBackend(decodedJson['access_token'] as String, context);
        } else {
          debugPrint('Error: access_token not found in JSON response');
        }
      }
    } catch (e) {
      debugPrint('Error decoding JSON: $e');
    }
  }

  Future<void> sendToBackend(
    String accessToken,
    BuildContext context, [
    String? tokenType,
  ]) async {
    try {
      final model = AzureTokenInputModel(
        accessToken: accessToken,
        idpName: idpName_shared_preferences ?? '',
        tokenType: tokenType,
      );
      final response = await _dio.post(
        '${Configuration.AuthUrl}/auth',
        data: model.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = AuthResponseModel.fromJson(response.data);
        debugPrint('Entities Length: ${responseData.entities.length}');
        if (responseData.entities.length == 1) {
          final entityDta = responseData.entities[0];
          debugPrint('Single Entity');
          final FlutterSecureStorage secureStorage = FlutterSecureStorage();
          final String jsonString = jsonEncode(response.data);
          await secureStorage.write(key: 'Entities_List', value: jsonString);
          await secureStorage.write(
            key: 'idpname_backend',
            value: responseData.idpname_backend,
          );
          if (context.mounted) {
            getJwtFromBackend(
              responseData.username,
              responseData.idpname_backend,
              entityDta.tenant,
              entityDta.refreshToken,
              deviceId_shared_preferences ?? '',
              context,
            );
          }
        } else {
          debugPrint('Multiple Entities');
          final FlutterSecureStorage secureStorage = FlutterSecureStorage();
          final String jsonString = jsonEncode(response.data);
          await secureStorage.write(key: 'Entities_List', value: jsonString);
          await secureStorage.write(
            key: 'idpname_backend',
            value: responseData.idpname_backend,
          );
          await secureStorage.delete(key: 'JWT_Token');
          if (context.mounted) {
            context.goNamed('/');
          }
        }
      } else {
        debugPrint('Backend error: ${response.statusCode} ${response.data}');
      }
    } catch (e) {
      debugPrint('Error sending tokens to backend: $e');
      if (e is DioException) {
        debugPrint('Request data: ${e.requestOptions.data}');
        debugPrint('Response data: ${e.response?.data}');
      }
    }
  }

  static Future<void> getJwtFromBackend(
    String username,
    String idpName,
    String tenant,
    String refreshToken,
    String deviceId,
    BuildContext context,
  ) async {
    try {
      final model = AudModel(
        username: username,
        idpName: idpName,
        tenant: tenant,
        refreshToken: refreshToken,
        deviceId: deviceId,
      );
      final response = await dio2.post(
        '${Configuration.AuthUrl}/aud',
        data: model.toJson(),
        options: Options(extra: {'_database_name': tenant}),
      );

      if (response.statusCode == 200) {
        final responseData = AuthTokenModel.fromJson(response.data);
        final FlutterSecureStorage secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'JWT_Token', value: responseData.token);
        await secureStorage.write(
          key: 'Refresh_Token',
          value: responseData.refreshToken,
        );
        await secureStorage.write(key: 'Username', value: username);
        if (context.mounted) {
          context.goNamed('/');
        }
      } else {
        debugPrint('Backend error: ${response.statusCode} ${response.data}');
      }
    } catch (e) {
      debugPrint('Error sending tokens to backend: $e');
      if (e is DioException) {
        debugPrint('Request data: ${e.requestOptions.data}');
        debugPrint('Response data: ${e.response?.data}');
      }
    }
  }
}
