import 'sdk_outputs.dart';

export 'sdk_outputs.dart' show AudTokenResponse, RefreshTokenResponse;

/// `/aud` response: JWT in `token`, portal refresh token in `refreshToken`.
class AuthTokenModel {
  final String token;
  final String refreshToken;

  AuthTokenModel({required this.token, required this.refreshToken});

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    final r = AudTokenResponse.fromJson(json);
    return AuthTokenModel(token: r.accessToken, refreshToken: r.refreshToken);
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'refreshToken': refreshToken,
  };

  AudTokenResponse get asAudTokenResponse =>
      AudTokenResponse(accessToken: token, refreshToken: refreshToken);
}
