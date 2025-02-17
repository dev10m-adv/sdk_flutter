class AuthResponseModel {
  final String errorDetails;
  final List<Entity> entities;
  final String username;
  final String idpname_backend;

  AuthResponseModel({
    required this.errorDetails,
    required this.entities,
    required this.username,
    required this.idpname_backend,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      errorDetails: json['ErrorDetails'] ?? '',
      username: json['Username'] ?? '',
      idpname_backend: json['idpname'] ?? '',
      entities: (json['Entities'] as List)
          .map((entity) => Entity.fromJson(entity))
          .toList(),
    );
  }
}

class Entity {
  final String tenant;
  final Authorization authorizations;
  final String refreshToken;

  Entity({
    required this.tenant,
    required this.authorizations,
    required this.refreshToken,
  });

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      tenant: json['tenant'] ?? '',
      authorizations: Authorization.fromJson(json['authorizations']),
      refreshToken: json['refreshtoken'] ?? '',
    );
  }
}

class Authorization {
  final List<String> roles;

  Authorization({required this.roles});

  factory Authorization.fromJson(Map<String, dynamic> json) {
    return Authorization(
      roles: List<String>.from(json['roles'] ?? []),
    );
  }
}
