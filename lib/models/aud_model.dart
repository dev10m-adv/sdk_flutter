class AudModel {
  final String username;
  final String tenant;
  final String refreshToken;
  final String deviceId;

  AudModel({
    required this.username,
    required this.tenant,
    required this.refreshToken,
    required this.deviceId,
  });

  factory AudModel.fromJson(Map<String, dynamic> json) {
    return AudModel(
      username: json['Username'] ?? '',
      tenant: json['Tenant'] ?? '',
      refreshToken: json['RefreshToken'] ?? '',
      deviceId: json['DeviceID'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Username': username,
      'Tenant': tenant,
      'RefreshToken': refreshToken,
      'DeviceID': deviceId,
    };
  }
}
