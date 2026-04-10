/// Stable, versioned response shapes for AdvComm Auth API consumers.
///
/// Parse server JSON with [AuthEntitiesResponse.fromJson], [AudTokenResponse.fromJson],
/// etc. Field names here use Dart conventions (`accessToken`); wire JSON may use
/// `Token`, `refresh_token`, etc. — factories normalize both.
library;

// --- Helpers -----------------------------------------------------------------

String _str(dynamic v) => v == null ? '' : '$v';

int _int(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

Map<String, dynamic> _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

// --- POST /auth, OTP verify (UserEntities body) ------------------------------

/// One tenant row for the signed-in subject (matches `GetUIDsBySubjectUIDAndAppPortalID`).
class TenantBinding {
  /// Tenant owner email (`users.user_name` for `tenant_id`).
  final String tenant;

  /// Role names from `authorizations.roles`.
  final List<String> roles;

  /// Hex-encoded refresh token for this portal + tenant row.
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
    return TenantBinding(
      tenant: _str(json['tenant']),
      roles: roles,
      refreshToken: _str(json['refresh_token'] ?? json['refreshtoken']),
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant': tenant,
        'roles': roles,
        'refreshToken': refreshToken,
      };
}

/// Successful or error payload from `POST /auth` and `POST /otpverify` (200 body).
class AuthEntitiesResponse {
  /// Empty when the login succeeded; otherwise a human-readable error.
  final String errorDetails;

  final String username;

  /// IdP label used for this flow (e.g. `Gmail`, `Email`).
  final String idpName;

  /// Tenant rows for this subject + portal (may be empty on error).
  final List<TenantBinding> entities;

  bool get isSuccess => errorDetails.isEmpty;

  const AuthEntitiesResponse({
    required this.errorDetails,
    required this.username,
    required this.idpName,
    required this.entities,
  });

  factory AuthEntitiesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['Entities'] ?? json['entities'];
    final list = raw is List ? raw : const [];
    return AuthEntitiesResponse(
      errorDetails: _str(json['ErrorDetails'] ?? json['errorDetails']),
      username: _str(json['Username'] ?? json['username']),
      idpName: _str(json['idpname'] ?? json['idpName']),
      entities: list.map((e) {
        final m = _map(e);
        return TenantBinding.fromJson(m);
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

// --- POST /aud ---------------------------------------------------------------

/// JWT + refresh bundle from `POST /aud`.
class AudTokenResponse {
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
      accessToken: _str(json['Token'] ?? json['token']),
      refreshToken: _str(json['RefreshToken'] ?? json['refresh_token']),
      isSuccess: json['IsSuccess'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'isSuccess': isSuccess,
      };
}

// --- POST /refresh -----------------------------------------------------------

/// New JWT + refresh from `POST /refresh`.
class RefreshTokenResponse {
  final String accessToken;
  final String refreshToken;

  const RefreshTokenResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      accessToken: _str(json['Token'] ?? json['token']),
      refreshToken: _str(json['RefreshToken'] ?? json['refresh_token']),
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

// --- POST /registerdevice ----------------------------------------------------

/// Result of `POST /registerdevice`.
class DeviceRegistrationResponse {
  final int deviceId;
  final String audDomain;

  /// Raw rows from `getappconfiguration` / `GetAppConfiguration` (keys may be snake_case).
  final List<Map<String, dynamic>> configurations;

  const DeviceRegistrationResponse({
    required this.deviceId,
    required this.audDomain,
    required this.configurations,
  });

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['Configurations'] ?? json['configurations'];
    final list = raw is List ? raw : const [];
    return DeviceRegistrationResponse(
      deviceId: _int(json['DeviceId'] ?? json['deviceId']),
      audDomain: _str(json['AudDomain'] ?? json['audDomain']),
      configurations: list.map((e) => _map(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'audDomain': audDomain,
        'configurations': configurations,
      };
}
