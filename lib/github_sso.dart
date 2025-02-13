// import 'dart:io';
// import 'package:uids_io_sdk_flutter/auth_view.dart';
// import 'package:uids_io_sdk_flutter/models/aud_model.dart';
// import 'package:uids_io_sdk_flutter/models/auth_response_model.dart';
// import 'package:uids_io_sdk_flutter/models/auth_token_model.dart';
// import 'package:uids_io_sdk_flutter/models/azure_token_input_model.dart';
// import 'package:uids_io_sdk_flutter/services/configuration_service.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:flutter/foundation.dart'; // For `kIsWeb`
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class GitHubSSO {
//   static Dio _dio = Dio();
//   static String apiUrl = 'https://auth1.3u.gg';
//   final ConfigurationService _configurationService = ConfigurationService();
//   late final GoogleSignIn _googleSignIn;
//   String? clientId_shared_preferences;
//   String? idpName_shared_preferences;
//   String? deviceId_shared_preferences;

//   GitHubSSO() {
//     _initialize();
//   }
//   Future<void> _initialize() async {
//     await _registerDeviceData();
//     await _initializeGitHubSignIn();
//   }

//   Future<void> _registerDeviceData() async {
//     try {
//       await _configurationService.registerDeviceData();
//     } catch (e) {
//       print('Error during device registration: $e');
//     }
//   }
//   Future<void> _initializeGitHubSignIn() async {
//     final prefs = await SharedPreferences.getInstance();
//     clientId_shared_preferences = prefs.getString('clientId');
//     idpName_shared_preferences = prefs.getString('idpName');
//     deviceId_shared_preferences = prefs.getString('deviceId');

//     print('Retrieved Client ID: $clientId_shared_preferences');
//     print('Retrieved IDP Name: $idpName_shared_preferences');
//     print('Retrieved Device ID: $deviceId_shared_preferences');

//     // Initialize Google Sign-In instances
//     _googleSignIn = GoogleSignIn(
//       clientId: clientId_shared_preferences,
//       scopes: ['email', 'profile', 'openid'],
//     );
//   }

//   Future<void> signInWithGitHub(BuildContext context) async {
//     if (kIsWeb) {
//       await _signInWithGoogleWeb(context);
//     } else if (Platform.isAndroid || Platform.isIOS) {
//       await _signInWithGoogleMobile(context);
//     } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
//       await _signInWithGoogleDesktop(context);
//     }
//   }

//   Future<void> _signInWithGoogleWeb(BuildContext context) async {
//     try {
//       final GoogleSignInAccount? account = await _googleSignIn.signIn();
//       if (account != null) {
//         final GoogleSignInAuthentication auth = await account.authentication;
//         if (auth.accessToken != null) {
//           print('Access Token: ${auth.accessToken}');
//           print('Id Token: ${auth.idToken}');
//           await sendToBackend(auth.accessToken!);
//         }
//       }
//     } catch (e) {
//       print('Error during Google Sign-In: $e');
//     }
//   }

//   Future<void> _signInWithGoogleMobile(BuildContext context) async {
//     try {
//       final GoogleSignInAccount? account = await _googleSignIn.signIn();
//       if (account != null) {
//         final GoogleSignInAuthentication auth = await account.authentication;
//         if (auth.accessToken != null) {
//           print('Access Token: ${auth.accessToken}');
//           print('ID Token: ${auth.idToken}');
//           await sendToBackend(auth.accessToken!);
//         } else {
//           print('Error: Missing access token or ID token');
//         }
//       }
//     } catch (e) {
//       print('Error during Google Sign-In: $e');
//     }
//   }

//   Future<void> _signInWithGoogleDesktop(BuildContext context) async {
//     try {
//       final String clientId = clientId_shared_preferences ?? '';
//       final String redirectUri = 'http://localhost:3001/callback';
//       const String authorizationEndpoint =
//           'https://accounts.google.com/o/oauth2/auth';
//       const String scope = 'openid email profile';

//       final String authUrl =
//           '$authorizationEndpoint?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&scope=$scope';
//       print('AuthUrl: $authUrl');
//       showDialog(
//         context: context,
//         barrierColor: Colors.black54, // Set a semi-transparent background
//         builder: (BuildContext context) {
//           return Dialog(
//             backgroundColor:
//                 Colors.transparent, // Make dialog background transparent
//             child: ConstrainedBox(
//               constraints: BoxConstraints(maxWidth: 600),
//               child: Container(
//                 width: double.maxFinite,
//                 height: 500,
//                 decoration: BoxDecoration(
//                   color:
//                       Colors.white, // Set the background color of the content
//                   borderRadius: BorderRadius.circular(8),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black26,
//                       blurRadius: 10,
//                       offset: Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: InAppWebView(
//                   initialUrlRequest: URLRequest(url: WebUri(authUrl)),
//                   onLoadStart: (controller, url) {
//                     print('Started loading: $url');
//                     if (url.toString().startsWith(redirectUri)) {
//                       final code =
//                           Uri.parse(url.toString()).queryParameters['code'];
//                       if (code != null) {
//                         print('Authorization code: $code');
//                         sendToBackend(code, 'authCode');
//                         if (Navigator.canPop(context)) {
//                           Navigator.of(context).pop(); // Close the popup
//                         }
//                       }
//                     }
//                   },
//                   onLoadStop: (controller, url) {
//                     print('Stopped loading: $url');
//                   },
//                   onLoadError: (controller, url, code, message) {
//                     print(
//                         'Error loading: $url, Code: $code, Message: $message');
//                   },
//                 ),
//               ),
//             ),
//           );
//         },
//       );
//     } catch (e) {
//       print('Error during OAuth on Desktop with InAppWebView: $e');
//     }
//   }

//   Future<void> sendToBackend(String accessToken, [String? tokenType]) async {
//     print('Function Send To Backend accessToken: $accessToken');
//     try {
//       final model = AzureTokenInputModel(
//           accessToken: accessToken,
//           idpName: idpName_shared_preferences ?? '');
//       final response = await _dio.post(
//         '$apiUrl/auth',
//         data: model.toJson(),
//       );

//       if (response.statusCode == 200) {
//         print('Response from backend: ${response.data}');
//         final responseData = AuthResponseModel.fromJson(response.data);
//           print('ErrorDetails: ${responseData.errorDetails}');
//           print('Username: ${responseData.username}');
//           print('Entities: ${responseData.entities}');
//           print('Entities Length: ${responseData.entities.length}');
//           if(responseData.entities.length == 1){
//             final entityDta = responseData.entities[0];
//             print('Single Entity tenant: ${entityDta.tenant}');
//             print('Single Entity refreshtoken: ${entityDta.refreshToken}');
//             getJwtFromBackend(responseData.username, entityDta.tenant, entityDta.refreshToken, deviceId_shared_preferences ?? '');
//           }else{
//             print('Multiple Entities');
//               List<String> tenantList = responseData.entities.map((e) => e.tenant).toList();
//               List<String> tokens = responseData.entities.map((e) => e.refreshToken).toList();

//               WidgetsBinding.instance.addPostFrameCallback((_) {
//                 if (globalKey.currentState != null) {
//                   globalKey.currentState!.switchScreen(
//                     "selectEntity",
//                     options: tenantList,
//                     user: responseData.username,
//                     device: deviceId_shared_preferences ?? '',
//                     tokens: tokens,
//                   );
//                 }
//               });
//           }
//       } else {
//         print('Backend error: ${response.statusCode} ${response.data}');
//       }
//     } catch (e) {
//       print('Error sending tokens to backend: $e');
//       if (e is DioError) {
//         print('Request data: ${e.requestOptions.data}');
//         print('Response data: ${e.response?.data}');
//       }
//     }
//   }
//   static Future<void> getJwtFromBackend(String username, String tenant,String refreshToken,String deviceId) async {
//     try {
//       final model = AudModel(
//           username: username,
//           tenant: tenant,
//           refreshToken: refreshToken,
//           deviceId: deviceId);
//       final response = await _dio.post(
//         '$apiUrl/aud',
//         data: model.toJson(),
//       );

//       if (response.statusCode == 200) {
//         final responseData = AuthTokenModel.fromJson(response.data);
//           print('JWT Token: ${responseData.token}');
//           print('RefreshToken: ${responseData.refreshToken}');
//           final prefs = await SharedPreferences.getInstance();
//           await prefs.setString('JWT_Token', responseData.token);
//           await prefs.setString('Refresh_Token', responseData.refreshToken);
//       } else {
//         print('Backend error: ${response.statusCode} ${response.data}');
//       }
//     } catch (e) {
//       print('Error sending tokens to backend: $e');
//       if (e is DioError) {
//         print('Request data: ${e.requestOptions.data}');
//         print('Response data: ${e.response?.data}');
//       }
//     }
//   }
// }
