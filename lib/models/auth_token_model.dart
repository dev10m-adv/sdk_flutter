class AuthTokenModel {
  final String token;
  final String refreshToken;

  AuthTokenModel({
    required this.token,
    required this.refreshToken,
  });

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      token: json['Token'] ?? '',
      refreshToken: json['RefreshToken'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Token': token,
      'RefreshToken': refreshToken,
    };
  }
}
