/// Request body for `POST /aud` — AdvComm camelCase.
class AudModel {
  final String username;
  final String tenant;
  final String refreshToken;
  final String deviceId;
  final String idpName;

  @Deprecated('Use idpName')
  String get idpname_backend => idpName;

  AudModel({
    required this.username,
    required this.tenant,
    required this.refreshToken,
    required this.deviceId,
    required this.idpName,
  });

  factory AudModel.fromJson(Map<String, dynamic> json) {
    return AudModel(
      username: json['username'] as String? ?? '',
      idpName: json['idpName'] as String? ?? '',
      tenant: json['tenant'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'tenant': tenant,
      'refreshToken': refreshToken,
      'deviceId': deviceId,
      'idpName': idpName,
    };
  }
}
