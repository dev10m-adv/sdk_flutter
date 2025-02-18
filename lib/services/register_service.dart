import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';

class RegisterService {
  static final Dio _dio = Dio();
  static final String apiUrl = Configuration.apiUrl;

  static Future<void> registerDeviceData() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    print('Registering device...');
    print(deviceInfo);
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
      'appdomain': 'auth1.3u.gg',
      'deviceType': deviceType,
      'deviceToken': deviceToken,
      'devicePlatform': devicePlatform,
    };
    try {
      await registerDevice(data);
    } catch (e) {
      print('Error during device registration: $e');
    }
  }

  static Future<void> registerDevice(Map<String, dynamic> data) async {
    final String url = '$apiUrl/registerdevice';
    print('Registering device with data: $data');

    try {
      final response = await _dio.post(
        url,
        data: data,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        print('Device registered successfully: ${response.data}');
        final responseData = response.data;

        if (responseData['IsSuccess'] == true) {
          final FlutterSecureStorage secureStorage = FlutterSecureStorage();
          final deviceId = responseData['DeviceId'];
          await secureStorage.write(key: "DeviceId", value: deviceId.toString());
          final configurations = responseData['Configurations'];
          if (configurations != null && configurations.isNotEmpty) {
            String jsonString = jsonEncode(configurations);
            await secureStorage.write(key: "Configurations", value: jsonString);
          }
        }
      } else {
        print(
            'Failed to register device: ${response.statusCode} ${response.data}');
      }
    } catch (e) {
      print('Error registering device: $e');
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
