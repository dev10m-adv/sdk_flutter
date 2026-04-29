import 'package:flutter_test/flutter_test.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';
import 'package:uids_io_sdk_flutter/models/sdk_outputs.dart';

void main() {
  test('configuration defaults are set', () {
    expect(Configuration.AuthUrl, isNotEmpty);
  });

  test('AuthEntitiesResponse parses camelCase AdvComm JSON', () {
    final r = AuthEntitiesResponse.fromJson({
      'errorDetails': '',
      'username': 'a@b.com',
      'idpName': 'Gmail',
      'entities': [
        {
          'tenant': 't@en.ant',
          'authorizations': {
            'roles': ['all'],
          },
          'refreshToken': 'abc123',
        },
      ],
    });
    expect(r.isSuccess, isTrue);
    expect(r.idpName, 'Gmail');
    expect(r.entities, hasLength(1));
    expect(r.entities.single.refreshToken, 'abc123');
    expect(r.entities.single.roles, ['all']);
  });

  test('AudTokenResponse parses camelCase /aud body', () {
    final t = AudTokenResponse.fromJson({
      'token': 'jwt',
      'refreshToken': 'rt',
      'isSuccess': true,
    });
    expect(t.accessToken, 'jwt');
    expect(t.refreshToken, 'rt');
    expect(t.isSuccess, isTrue);
  });

  test('RefreshTokenResponse parses camelCase /refresh body', () {
    final t = RefreshTokenResponse.fromJson({
      'token': 'newJwt',
      'refreshToken': 'newRt',
    });
    expect(t.accessToken, 'newJwt');
    expect(t.refreshToken, 'newRt');
  });

  test('DeviceRegistrationResponse parses camelCase', () {
    final d = DeviceRegistrationResponse.fromJson({
      'isSuccess': true,
      'deviceId': 42,
      'audDomain': 'https://aud.example',
      'configurations': [
        {'idpName': 'Gmail'},
      ],
    });
    expect(d.isSuccess, isTrue);
    expect(d.deviceId, 42);
    expect(d.audDomain, 'https://aud.example');
    expect(d.configurations, hasLength(1));
    expect(d.configurations.single['idpName'], 'Gmail');
  });
}
