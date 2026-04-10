import 'sdk_outputs.dart';

export 'sdk_outputs.dart';

/// OAuth / IdP authorization payload nested under each [Entity].
class Authorization {
  final List<String> roles;

  const Authorization({required this.roles});

  factory Authorization.fromJson(Map<String, dynamic> json) {
    return Authorization(
      roles: List<String>.from(json['roles'] ?? []),
    );
  }
}

/// Legacy wrapper around [TenantBinding] (keeps [authorizations] for old code).
class Entity {
  final TenantBinding _binding;

  Entity._(this._binding);

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity._(TenantBinding.fromJson(json));
  }

  factory Entity._fromTenantBinding(TenantBinding b) => Entity._(b);

  String get tenant => _binding.tenant;

  String get refreshToken => _binding.refreshToken;

  Authorization get authorizations =>
      Authorization(roles: _binding.roles);

  /// Use this in new code instead of [Entity].
  TenantBinding get asTenantBinding => _binding;
}

/// Legacy name for [AuthEntitiesResponse]. Prefer [AuthEntitiesResponse] in new apps.
class AuthResponseModel {
  final String errorDetails;
  final String username;
  final String idpName;
  final List<Entity> entities;

  @Deprecated('Use idpName')
  String get idpname_backend => idpName;

  AuthResponseModel({
    required this.errorDetails,
    required this.username,
    required this.idpName,
    required this.entities,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final r = AuthEntitiesResponse.fromJson(json);
    return AuthResponseModel(
      errorDetails: r.errorDetails,
      username: r.username,
      idpName: r.idpName,
      entities: r.entities.map(Entity._fromTenantBinding).toList(),
    );
  }

  /// Fixed-shape output for SDK consumers (no legacy field names).
  AuthEntitiesResponse get asCanonical => AuthEntitiesResponse(
        errorDetails: errorDetails,
        username: username,
        idpName: idpName,
        entities: entities.map((e) => e.asTenantBinding).toList(),
      );
}
