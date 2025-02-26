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
      accessToken: json['AccessToken'] ?? '',
      idpName: json['idpName'] ?? '',
      tokenType: json['tokenType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AccessToken': accessToken,
      'idpName': idpName,
      if (tokenType != null) 'tokenType': tokenType,
    };
  }
}

