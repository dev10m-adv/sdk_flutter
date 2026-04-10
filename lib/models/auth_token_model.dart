import 'sdk_outputs.dart';

export 'sdk_outputs.dart' show AudTokenResponse, RefreshTokenResponse;

/// Legacy adapter: `/aud` returns `Token` / `RefreshToken`; use [AudTokenResponse] in new code.
class AuthTokenModel {
  final String token;
  final String refreshToken;

  AuthTokenModel({
    required this.token,
    required this.refreshToken,
  });

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    final r = AudTokenResponse.fromJson(json);
    return AuthTokenModel(token: r.accessToken, refreshToken: r.refreshToken);
  }

  Map<String, dynamic> toJson() => {
        'Token': token,
        'RefreshToken': refreshToken,
      };

  AudTokenResponse get asAudTokenResponse => AudTokenResponse(
        accessToken: token,
        refreshToken: refreshToken,
      );
}
