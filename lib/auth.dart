import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';
import 'package:flutter/material.dart';
import 'package:uids_io_sdk_flutter/gmail_sso.dart';
import 'package:uids_io_sdk_flutter/models/auth_response_model.dart';

Future<void> loginWithCredentials(String email, String password) async {
  Dio dio = Dio();
  final String apiUrl = Configuration.apiUrl;
  final String url = '$apiUrl/login';
  try {
    final response = await dio.post(
      url,
      data: {
        'email': email,// change this to username
        'password': password,
      },
    );
    if (response.statusCode == 200) {
      final String accessToken = response.data['accessToken'];
      if (accessToken.isNotEmpty) {
        final FlutterSecureStorage secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: "opt_access_token", value: accessToken);
      } else {
        throw 'Invalid access token';
      }
    } else {
      throw response.data['message'] ?? 'Registration failed';
    }
  } on DioException catch (e) {
    String errorMessage = 'Error during login';
    if (e.response != null && e.response?.data != null) {
      errorMessage = e.response?.data['message'] ?? errorMessage;
    }
    throw errorMessage; // Throw only the error message
  } catch (e) {
    throw 'Error during login'; // Catch any other unknown errors
  }
}

Future<void> registerUser(String username, String email, String password,
    BuildContext context) async {
  Dio dio = Dio();
  final String apiUrl = Configuration.apiUrl;
  final String url = '$apiUrl/register';

  try {
    final response = await dio.post(
      url,
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final String qrCodeDataURL = response.data['qrCodeDataURL'];
      final String accessToken = response.data['accessToken'];
      if (qrCodeDataURL.isNotEmpty && accessToken.isNotEmpty) {
        _showQrCodePopup(context, qrCodeDataURL, accessToken);
      } else {
        throw 'Invalid QR code or access token';
      }
    } else {
      throw response.data['message'] ?? 'Registration failed';
    }
  } on DioException catch (e) {
    String errorMessage = 'Error during registration';
    if (e.response != null && e.response?.data != null) {
      errorMessage = e.response?.data['message'] ?? errorMessage;
    }
    throw errorMessage; // Throw only the error message
  } catch (e) {
    throw 'Error during registration'; // Catch any other unknown errors
  }
}

void _showQrCodePopup(
    BuildContext context, String qrCodeDataURL, String accessToken) {
  TextEditingController pinController = TextEditingController();
  bool isPinCorrect = false; // Flag to track pin validity

  showDialog(
    context: context,
    barrierDismissible:
        false, // Prevent dismissing by tapping outside the dialog
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display the QR code as an image using the qrCodeDataURL
            Image.network(qrCodeDataURL), // Directly display the image from URL
            const SizedBox(height: 20),
            const Text(
                'Scan this QR code for verification or further actions.'),
            const SizedBox(height: 20),
            // Input field for 6-digit pin
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'Enter 6-digit pin',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6, // Limit to 6 digits
              obscureText:
                  false, // Not needed for pin, but could be useful for security
              onChanged: (value) {
                // Check if the pin is 6 digits
                isPinCorrect = value.length == 6;
              },
            ),
          ],
        ),
        actions: [
          // Continue button to verify pin and close the dialog
          ElevatedButton(
            onPressed: () async {
              // Verify OTP if pin is correct
              if (isPinCorrect) {
                try {
                  // Call verifyOtp function when pin is correct
                  await verifyOtp(pinController.text, accessToken, context);

                  // Close the dialog after successful OTP verification
                  Navigator.of(context).pop();
                } catch (e) {
                  // Show error message if OTP verification fails
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Invalid pin, please try again')),
                  );
                }
              } else {
                // Show an error message if pin is incorrect
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Invalid pin, please try again')),
                );
              }
            },
            child: const Text('Continue'),
          ),
          // Disable Close button if pin is incorrect
          if (isPinCorrect)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the popup
              },
              child: const Text('Close'),
            ),
        ],
      );
    },
  );
}

Future<void> verifyOtp(
    String otp, String accessToken, BuildContext context) async {
  Dio dio = Dio();
  final String apiUrl = Configuration.apiUrl;
  final String url = '$apiUrl/otpverify';

  try {
    final response = await dio.post(
      url,
      data: {
        'otp': otp, // OTP provided by the user
      },
      options: Options(
        headers: {
          'Authorization':
              'Bearer $accessToken', // Include Bearer token in the header
        },
      ),
    );

    if (response.statusCode == 200) {
      final FlutterSecureStorage secureStorage = FlutterSecureStorage();
      await secureStorage.delete(key: "opt_access_token");
      print('Response from backend: ${response.data}');
      final responseData = AuthResponseModel.fromJson(response.data);
      print('ErrorDetails: ${responseData.errorDetails}');
      print('Username: ${responseData.username}');
      print('idpname: ${responseData.idpname_backend}');
      print('Entities: ${responseData.entities}');
      print('Entities Length: ${responseData.entities.length}');
      if (responseData.entities.length == 1) {
        final entityDta = responseData.entities[0];
        print('Single Entity tenant: ${entityDta.tenant}');
        print('Single Entity refreshtoken: ${entityDta.refreshToken}');

        String jsonString = jsonEncode(response.data);
        await secureStorage.write(key: "Entities_List", value: jsonString);
        await secureStorage.write(key: "idpname_backend", value: responseData.idpname_backend);
        String? deviceId = await secureStorage.read(key: "deviceId");
        GmailSSO.getJwtFromBackend(responseData.username,responseData.idpname_backend, entityDta.tenant,
            entityDta.refreshToken, deviceId ?? '', context);
      } else {
        print('Multiple Entities');
        String jsonString = jsonEncode(response.data);
        await secureStorage.write(key: "Entities_List", value: jsonString);
        await secureStorage.delete(key: "JWT_Token");
        context.goNamed('/');
      }
    } else {
      throw response.data['message'] ?? 'Error during OTP verification';
    }
  } on DioException catch (e) {
    String errorMessage = 'Error during OTP verification';
    if (e.response != null && e.response?.data != null) {
      errorMessage = e.response?.data['message'] ?? errorMessage;
    }
    throw errorMessage; // Throw only the error message
  } catch (e) { // Catch any other unknown errors
     print('Error during OTP verification: $e');
    throw Exception('Error during OTP verification');
  }

}
