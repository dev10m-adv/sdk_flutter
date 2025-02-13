class AzureTokenInputModel {
  final String accessToken;
  final String idpName;

  AzureTokenInputModel({
    required this.accessToken,
    required this.idpName,
  });

  factory AzureTokenInputModel.fromJson(Map<String, dynamic> json) {
    return AzureTokenInputModel(
      accessToken: json['AccessToken'] ?? '',
      idpName: json['idpName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AccessToken': accessToken,
      'idpName': idpName,
    };
  }
}

