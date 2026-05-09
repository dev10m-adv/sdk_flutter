import 'package:flutter_test/flutter_test.dart';
import 'package:uids_io_sdk_flutter/uids_io_sdk_flutter.dart';

void main() {
  test('uids sdk config stores required values', () {
    final config = UidsSdkConfig(
      apiBaseUrl: Uri.parse('https://api.example.com'),
      authBaseUrl: Uri.parse('https://auth.example.com'),
      clientId: 'client-id',
      audience: 'audience',
      google: const GoogleAuthConfig(webClientId: 'web-id'),
    );

    expect(config.apiBaseUrl, Uri.parse('https://api.example.com'));
    expect(config.authBaseUrl, Uri.parse('https://auth.example.com'));
    expect(config.clientId, 'client-id');
    expect(config.audience, 'audience');
    expect(config.google?.webClientId, 'web-id');
  });

  test('auth session parses backend auth payload', () {
    final session = AuthSession.fromJson({
      'accessToken': 'jwt',
      'refreshToken': 'refresh',
      'accessTokenExpiresAt': '2030-01-01T00:00:00.000Z',
      'refreshTokenExpiresAt': '2030-02-01T00:00:00.000Z',
      'username': 'a@b.com',
      'idpName': 'Gmail',
    });

    expect(session.accessToken, 'jwt');
    expect(session.refreshToken, 'refresh');
    expect(session.user.email, 'a@b.com');
    expect(session.provider, AuthProvider.google);
    expect(session.authorizationHeader, 'Bearer jwt');
  });

  test('registered device parses backend payload', () {
    final device = RegisteredDevice.fromJson({
      'id': 'device-1',
      'stable_device_key': 'stable-key',
      'platform': 'windows',
      'device_name': 'Workstation',
      'registered_at': '2030-01-01T00:00:00.000Z',
    });

    expect(device.id, 'device-1');
    expect(device.stableDeviceKey, 'stable-key');
    expect(device.platform, 'windows');
    expect(device.deviceName, 'Workstation');
  });
}
