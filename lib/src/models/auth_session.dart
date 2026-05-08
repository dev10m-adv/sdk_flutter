import 'auth_provider.dart';
import 'auth_user.dart';

/// Backend session returned after successful provider token exchange.
final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.user,
    required this.provider,
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;

  /// Always store expiry in UTC to avoid client/server timezone issues.
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;

  final AuthUser user;
  final AuthProvider provider;
  final String tokenType;

  bool get isExpired =>
      DateTime.now().toUtc().isAfter(accessTokenExpiresAt.toUtc());

  bool get isRefreshTokenExpired =>
      DateTime.now().toUtc().isAfter(refreshTokenExpiresAt.toUtc());

  bool isExpiredWithBuffer(Duration buffer) {
    final expiryWithBuffer = accessTokenExpiresAt.toUtc().subtract(buffer);
    return DateTime.now().toUtc().isAfter(expiryWithBuffer);
  }

  String get authorizationHeader => '$tokenType $accessToken';

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenExpiresAt: _readDateTime(json['accessTokenExpiresAt']),
      refreshTokenExpiresAt: _readDateTime(json['refreshTokenExpiresAt']),
      user: AuthUser.temp(json['username'] as String),

      /// Supports both backend `idpName` and local `provider`.
      provider: _readProvider(
        json['idpName'] ?? json['provider'],
      ),

      tokenType: json['tokenType'] as String? ?? 'Bearer',
    );
  }

  static AuthProvider _readProvider(Object? value) {
    final provider = value?.toString().toLowerCase().trim();

    switch (provider) {
      case 'google':
      case 'gmail':
        return AuthProvider.google;

      case 'microsoft':
      case 'outlook':
        return AuthProvider.microsoft;

      default:
        throw FormatException('Unknown provider: $value');
    }
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiresAt': accessTokenExpiresAt.toUtc().toIso8601String(),
        'refreshTokenExpiresAt':
            refreshTokenExpiresAt.toUtc().toIso8601String(),
        'username': user.email,
        'provider': provider.name,
        'tokenType': tokenType,
      };

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
    AuthUser? user,
    AuthProvider? provider,
    String? tokenType,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
      user: user ?? this.user,
      provider: provider ?? this.provider,
      tokenType: tokenType ?? this.tokenType,
    );
  }

  static DateTime _readDateTime(Object? value) {
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    throw FormatException('Invalid DateTime value: $value');
  }

  @override
  String toString() {
    return 'AuthSession(user: ${user.email}, '
        'accessTokenExpiresAt: $accessTokenExpiresAt, '
        'refreshTokenExpiresAt: $refreshTokenExpiresAt, '
        'expired: $isExpired)';
  }
}
