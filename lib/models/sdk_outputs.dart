/// Response DTOs for AdvComm Auth API (camelCase JSON, matching Express `res.json`).
///
/// Servers must send lowercase/camelCase wire keys (`token`, `refreshToken`,
/// `entities`, …). Parsing does not accept legacy PascalCase/snake mixes.
library;

// --- Helpers -----------------------------------------------------------------

String _str(dynamic v) => v == null ? '' : '$v';

int _int(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

bool _bool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  return fallback;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

// --- POST /auth, POST /otpVerify (UserEntities body) --------------------------

/// One UID / tenant row for the signed-in subject.
///
/// AuthAPI returns these rows from DB procedures; wire keys may be camelCase
/// (`refreshToken`) or snake_case (`refresh_token`) depending on driver/serialization.
class TenantBinding {
  final String tenant;
  final List<String> roles;
  final String refreshToken;

  const TenantBinding({
    required this.tenant,
    required this.roles,
    required this.refreshToken,
  });

  factory TenantBinding.fromJson(Map<String, dynamic> json) {
    final auth = json['authorizations'];
    List<String> roles = [];
    if (auth is Map<String, dynamic>) {
      roles = List<String>.from(auth['roles'] ?? []);
    }
    final rt = _str(json['refreshToken']);
    final refreshToken =
        rt.isNotEmpty ? rt : _str(json['refresh_token']);
    return TenantBinding(
      tenant: _str(json['tenant']),
      roles: roles,
      refreshToken: refreshToken,
    );
  }

  Map<String, dynamic> toJson() => {
    'tenant': tenant,
    'refreshToken': refreshToken,
    'authorizations': {'roles': roles},
  };
}

class AuthEntitiesResponse {
  final String errorDetails;
  final String username;
  final String idpName;
  final List<TenantBinding> entities;

  bool get isSuccess => errorDetails.isEmpty;

  const AuthEntitiesResponse({
    required this.errorDetails,
    required this.username,
    required this.idpName,
    required this.entities,
  });

  factory AuthEntitiesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['entities'];
    final list = raw is List ? raw : const [];
    return AuthEntitiesResponse(
      errorDetails: _str(json['errorDetails']),
      username: _str(json['username']),
      idpName: _str(json['idpName']),
      entities: list.map((e) {
        return TenantBinding.fromJson(_map(e));
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'errorDetails': errorDetails,
    'username': username,
    'idpName': idpName,
    'entities': entities.map((e) => e.toJson()).toList(),
  };
}

// --- POST /aud ----------------------------------------------------------------

/// JWT access token + portal refresh token from `POST /aud`.
class AudTokenResponse {
  /// JWT access token (`token` on the wire — same semantics as OAuth “access”).
  final String accessToken;
  final String refreshToken;
  final bool isSuccess;

  const AudTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.isSuccess = true,
  });

  factory AudTokenResponse.fromJson(Map<String, dynamic> json) {
    return AudTokenResponse(
      accessToken: _str(json['token']),
      refreshToken: _str(json['refreshToken']),
      isSuccess: _bool(json['isSuccess'], true),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': accessToken,
    'refreshToken': refreshToken,
    'isSuccess': isSuccess,
  };
}

// --- POST /refresh -------------------------------------------------------------

/// New JWT + refresh bundle from `POST /refresh`.
class RefreshTokenResponse {
  final String accessToken;
  final String refreshToken;

  const RefreshTokenResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      accessToken: _str(json['token']),
      refreshToken: _str(json['refreshToken']),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': accessToken,
    'refreshToken': refreshToken,
  };
}

// --- POST /registerDevice ------------------------------------------------------

class DeviceRegistrationResponse {
  final bool isSuccess;
  final int deviceId;
  final String audDomain;
  final List<Map<String, dynamic>> configurations;

  const DeviceRegistrationResponse({
    required this.isSuccess,
    required this.deviceId,
    required this.audDomain,
    required this.configurations,
  });

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['configurations'];
    final list = raw is List ? raw : const [];
    return DeviceRegistrationResponse(
      isSuccess: _bool(json['isSuccess'], false),
      deviceId: _int(json['deviceId']),
      audDomain: _str(json['audDomain']),
      configurations: list.map((e) => _map(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'isSuccess': isSuccess,
    'deviceId': deviceId,
    'audDomain': audDomain,
    'configurations': configurations,
  };
}
