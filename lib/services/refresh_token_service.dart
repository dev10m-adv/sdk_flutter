import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';

class RefreshTokenService {
  final Dio _dio = Dio();
  final String _refreshUrl = '${Configuration.AuthUrl}/refresh';
  Timer? _timer;

  RefreshTokenService() {
    _startTokenRefreshTimer();
  }

  /// Starts a timer that calls `checkAndRefreshToken` every 5 minutes
  void _startTokenRefreshTimer() {
    _timer?.cancel(); // Cancel any existing timer before starting a new one
    _timer = Timer.periodic(const Duration(minutes: 5), (Timer t) {
      checkAndRefreshToken();
    });
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<void> checkAndRefreshToken() async {
    print('Checking and refreshing token...');
    final FlutterSecureStorage secureStorage = FlutterSecureStorage();
    final String? jwtToken = await secureStorage.read(key: "JWT_Token");
    if (jwtToken != null && jwtToken.isNotEmpty) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(jwtToken);
      int exp = decodedToken['exp'];
      int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int remainingTime = exp - currentTime;
      double remainingTimeInMinutes = remainingTime / 60;
      if (remainingTimeInMinutes < 10) {
        print('Token is about to expire. Refreshing token...');
        final String? refreshToken = await secureStorage.read(key: "Refresh_Token");
        final String? username = await secureStorage.read(key: "Username");
        if (refreshToken != null && username != null) {
          print(username);
            print(refreshToken);
          await _refreshToken(refreshToken, username);
        } else {
          print('Refresh token or username is null');
        }
      } else {
         String formattedTime = remainingTimeInMinutes.toStringAsFixed(0);
        print("Remaining time before token expires: $formattedTime minutes");
      }
    } else {
      print('No Jwt token found...');
    }
  }

  Future<void> _refreshToken(String refreshToken, String username) async {
  try {
    final response = await _dio.post(
      _refreshUrl,
      data: {
        'RefreshToken': refreshToken,
        'Username': username,
      },
    );

    // Debugging: Print the full API response
    print('API Response: ${response.data}');

    if (response.statusCode == 200) {
      // Check if the response contains the expected keys
      if (response.data != null &&
          response.data['Token'] != null &&
          response.data['RefreshToken'] != null) {
        final newJwtToken = response.data['Token'] as String;
        final newRefreshToken = response.data['RefreshToken'] as String;

        final FlutterSecureStorage secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: "JWT_Token", value: newJwtToken);
        await secureStorage.write(key: "Refresh_Token", value: newRefreshToken);
        print('Token refreshed successfully');
      } else {
        print('Invalid response format: Missing Token or RefreshToken');
      }
    } else {
      print('Failed to refresh token: ${response.statusCode}');
    }
  } catch (e) {
    print('Error refreshing token: $e');
  }
}
}