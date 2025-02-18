import 'dart:io';

import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';

class ConfigurationService {
  final Dio _dio = Dio();
  final String apiUrl = Configuration.apiUrl;
  Future<void> registerDeviceData() async {
    final ConfigurationService _configurationService = ConfigurationService();
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    print('Registering device...');
    print(deviceInfo);
    String deviceType;
    String devicePlatform;
    String deviceToken = 'abc123token';

    if (kIsWeb) {
      WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      deviceType = 'Browser';
      devicePlatform = 'Web';
      deviceToken = webInfo.hashCode.toString();
    } else if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceType = 'Smartphone';
      devicePlatform = 'Android';
      deviceToken = androidInfo.hashCode.toString();
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceType = 'Smartphone';
      devicePlatform = 'iOS';
      deviceToken = iosInfo.hashCode.toString();
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      deviceType = 'Desktop';
      devicePlatform = 'Windows';
      deviceToken = windowsInfo.deviceId;
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macInfo = await deviceInfo.macOsInfo;
      deviceType = 'Desktop';
      devicePlatform = 'macOS';
      deviceToken = macInfo.hashCode.toString();
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
      deviceType = 'Desktop';
      devicePlatform = 'Linux';
      deviceToken = linuxInfo.hashCode.toString();
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
    await _configurationService.registerDevice(data);
  }

  Future<void> registerDevice(Map<String, dynamic> data) async {
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

      print('Response: ${response.data}');
      if (response.statusCode == 200) {
        print('Device registered successfully: ${response.data}');
        final responseData = response.data;

        if (responseData['IsSuccess'] == true) {
          final configurations = responseData['Configurations'];
          if (configurations != null && configurations.isNotEmpty) {
            // Find configuration where idpname is "Gmail"
            final config = configurations.firstWhere(
              (config) => config['idpname'] == 'Gmail',
              orElse: () => null, // Avoids crash if no match is found
            );

            if (config != null) {
              final clientConfig = config['appidpclientconfiguration'];
              final clientId = clientConfig?['CLIENT_ID'] ?? '';
              final idpName = config['idpname'];
              final deviceId = responseData['DeviceId'];

              print('Client Id: $clientId');
              print('IDP Name: $idpName');
              print('Device ID: $deviceId');

              final FlutterSecureStorage secureStorage = FlutterSecureStorage();
              await secureStorage.write(key: "clientId", value: clientId);
              await secureStorage.write(key: "idpName", value: idpName);
              await secureStorage.write(key: "deviceId", value: deviceId.toString());
            } else {
              print('No configuration found for Gmail');
            }
          }
        }
      }
      else {
        print(
            'Failed to register device: ${response.statusCode} ${response.data}');
      }
    } catch (e) {
      print('Error registering device: $e');
    }
  }
}
