import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';
import 'package:uids_io_sdk_flutter/models/sdk_outputs.dart';
import 'package:uids_io_sdk_flutter/src/sdk_log.dart';

class RegisterService {
  static final Dio _dio = Dio();
  static final String authUrl = Configuration.AuthUrl;

  static Future<void> registerDeviceData() async {
    sdkLogInfo('device', 'registerDeviceData started');
    String deviceType;
    String devicePlatform;
    String deviceToken = await getDeviceToken();

    if (kIsWeb) {
      deviceType = 'Browser';
      devicePlatform = 'Web';
    } else if (Platform.isAndroid) {
      deviceType = 'Smartphone';
      devicePlatform = 'Android';
    } else if (Platform.isIOS) {
      deviceType = 'Smartphone';
      devicePlatform = 'iOS';
    } else if (Platform.isWindows) {
      deviceType = 'Desktop';
      devicePlatform = 'Windows';
    } else if (Platform.isMacOS) {
      deviceType = 'Desktop';
      devicePlatform = 'macOS';
    } else if (Platform.isLinux) {
      deviceType = 'Desktop';
      devicePlatform = 'Linux';
    } else {
      deviceType = 'Unknown';
      devicePlatform = 'Unknown';
    }

    Map<String, dynamic> data = {
      'deviceType': deviceType,
      'deviceToken': deviceToken,
      'devicePlatform': devicePlatform,
    };
    try {
      await registerDevice(data);
    } catch (e, st) {
      sdkLogError('device', 'registerDeviceData failed', error: e, stackTrace: st);
    }
  }

  static Future<void> registerDevice(Map<String, dynamic> data) async {
    final String url = '$authUrl/registerdevice';
    try {
      final response = await _dio.post(
        url,
        data: data,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final parsed = DeviceRegistrationResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final FlutterSecureStorage secureStorage = FlutterSecureStorage();
        if (parsed.audDomain != Configuration.AudDomain) {
          sdkLogWarning(
            'device',
            'AudDomain mismatch: Configuration.AudDomain=${Configuration.AudDomain} '
            'server=${parsed.audDomain}',
          );
        }
        await secureStorage.write(
          key: "DeviceId",
          value: parsed.deviceId.toString(),
        );
        if (parsed.configurations.isNotEmpty) {
          final jsonString = jsonEncode(parsed.configurations);
          await secureStorage.write(key: "Configurations", value: jsonString);
        }
        sdkLogDebug('device', 'registerdevice ok deviceId=${parsed.deviceId}');
      } else {
        sdkLogWarning(
          'device',
          'registerdevice failed: status=${response.statusCode}',
        );
      }
    } on DioException catch (e, st) {
      sdkLogError(
        'device',
        dioErrorSummary(e),
        error: e,
        stackTrace: st,
      );
    } catch (e, st) {
      sdkLogError('device', 'register device failed', error: e, stackTrace: st);
    }
  }
}

Future<String> getDeviceToken() async {
  const String chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  Random random = Random();
  FlutterSecureStorage storage = FlutterSecureStorage();
  String? storedToken = await storage.read(key: 'DeviceToken');
  if (storedToken != null) {
    return storedToken;
  } else {
    String newToken =
        List.generate(10, (index) => chars[random.nextInt(chars.length)])
            .join();
    await storage.write(key: 'DeviceToken', value: newToken);
    return newToken;
  }
}
