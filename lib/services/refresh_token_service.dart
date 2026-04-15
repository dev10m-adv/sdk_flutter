import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';
import 'package:uids_io_sdk_flutter/models/sdk_outputs.dart';
import 'package:uids_io_sdk_flutter/src/sdk_log.dart';

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
    sdkLogDebug('token', 'checkAndRefreshToken tick');
    final FlutterSecureStorage secureStorage = FlutterSecureStorage();
    final String? jwtToken = await secureStorage.read(key: "JWT_Token");
    if (jwtToken != null && jwtToken.isNotEmpty) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(jwtToken);
      int exp = decodedToken['exp'];
      int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int remainingTime = exp - currentTime;
      double remainingTimeInMinutes = remainingTime / 60;
      if (remainingTimeInMinutes < 10) {
        sdkLogInfo('token', 'JWT expiring soon, attempting refresh');
        final String? refreshToken = await secureStorage.read(key: "Refresh_Token");
        final String? username = await secureStorage.read(key: "Username");
        if (refreshToken != null && username != null) {
          await _refreshToken(refreshToken, username);
        } else {
          sdkLogWarning('token', 'refresh skipped: missing refresh token or username');
        }
      } else {
        final String formattedTime = remainingTimeInMinutes.toStringAsFixed(0);
        sdkLogDebug(
          'token',
          'JWT still valid (~$formattedTime min remaining)',
        );
      }
    } else {
      sdkLogDebug('token', 'no JWT in storage, skip refresh');
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

      if (response.statusCode == 200 && response.data is Map) {
        final parsed = RefreshTokenResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        if (parsed.accessToken.isNotEmpty && parsed.refreshToken.isNotEmpty) {
          final FlutterSecureStorage secureStorage = FlutterSecureStorage();
          await secureStorage.write(key: "JWT_Token", value: parsed.accessToken);
          await secureStorage.write(
            key: "Refresh_Token",
            value: parsed.refreshToken,
          );
          sdkLogInfo('token', 'JWT refresh succeeded (tokens updated)');
        } else {
          sdkLogWarning('token', 'refresh response missing token fields');
        }
      } else {
        sdkLogWarning(
          'token',
          'refresh failed: status=${response.statusCode}',
        );
      }
    } on DioException catch (e, st) {
      sdkLogError(
        'token',
        dioErrorSummary(e),
        error: e,
        stackTrace: st,
      );
    } catch (e, st) {
      sdkLogError('token', 'refresh failed', error: e, stackTrace: st);
    }
  }
}