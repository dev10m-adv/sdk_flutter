class AudModel {
  final String username;
  final String tenant;
  final String refreshToken;
  final String deviceId;
  final String idpname_backend;

  AudModel({
    required this.username,
    required this.tenant,
    required this.refreshToken,
    required this.deviceId,
    required this.idpname_backend,
  });

  factory AudModel.fromJson(Map<String, dynamic> json) {
    return AudModel(
      username: json['Username'] ?? '',
      idpname_backend: json['IdpName'] ?? '',
      tenant: json['Tenant'] ?? '',
      refreshToken: json['RefreshToken'] ?? '',
      deviceId: json['DeviceID'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Username': username,
      'IdpName': idpname_backend,
      'Tenant': tenant,
      'RefreshToken': refreshToken,
      'DeviceID': deviceId,
    };
  }
}
