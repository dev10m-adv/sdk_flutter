/// Request body for `POST /auth` — AdvComm camelCase (`accessToken`, `idpName`, `tokenType`).
class AzureTokenInputModel {
  final String accessToken;
  final String idpName;
  final String? tokenType;

  AzureTokenInputModel({
    required this.accessToken,
    required this.idpName,
    this.tokenType,
  });

  factory AzureTokenInputModel.fromJson(Map<String, dynamic> json) {
    return AzureTokenInputModel(
      accessToken: json['accessToken'] as String? ?? '',
      idpName: json['idpName'] as String? ?? '',
      tokenType: json['tokenType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'idpName': idpName,
      if (tokenType != null) 'tokenType': tokenType,
    };
  }
}
