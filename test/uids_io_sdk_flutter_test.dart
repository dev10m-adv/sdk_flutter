import 'package:flutter_test/flutter_test.dart';
import 'package:uids_io_sdk_flutter/configuration.dart';
import 'package:uids_io_sdk_flutter/models/sdk_outputs.dart';

void main() {
  test('configuration defaults are set', () {
    expect(Configuration.AuthUrl, isNotEmpty);
  });

  test('AuthEntitiesResponse normalizes server JSON', () {
    final r = AuthEntitiesResponse.fromJson({
      'ErrorDetails': '',
      'Username': 'a@b.com',
      'idpname': 'Gmail',
      'Entities': [
        {
          'tenant': 't@en.ant',
          'authorizations': {'roles': ['all']},
          'refresh_token': 'abc123',
        },
      ],
    });
    expect(r.isSuccess, isTrue);
    expect(r.idpName, 'Gmail');
    expect(r.entities, hasLength(1));
    expect(r.entities.single.refreshToken, 'abc123');
    expect(r.entities.single.roles, ['all']);
  });

  test('AudTokenResponse accepts Token / RefreshToken', () {
    final t = AudTokenResponse.fromJson({
      'Token': 'jwt',
      'RefreshToken': 'rt',
      'IsSuccess': true,
    });
    expect(t.accessToken, 'jwt');
    expect(t.refreshToken, 'rt');
  });
}
