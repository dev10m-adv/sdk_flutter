/// Request body for `POST /aud` (wire format uses PascalCase keys in [toJson]).
class AudModel {
  final String username;
  final String tenant;
  final String refreshToken;
  final String deviceId;

  /// IdP name (e.g. `Gmail`, `Email`).
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
      username: json['Username'] ?? '',
      idpName: json['IdpName'] ?? '',
      tenant: json['Tenant'] ?? '',
      refreshToken: json['RefreshToken'] ?? '',
      deviceId: json['DeviceID'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Username': username,
      'IdpName': idpName,
      'Tenant': tenant,
      'RefreshToken': refreshToken,
      'DeviceID': deviceId,
    };
  }
}
