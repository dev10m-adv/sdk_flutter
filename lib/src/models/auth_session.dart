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
      provider: _readProvider(json['idpName'] ?? json['provider']),

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

  /// Serialises the session for secure-storage caching.
  ///
  /// Expiry values are stored as **Unix epoch seconds** (int) so that the
  /// cached value matches what the backend JWT carries and avoids any ISO-8601
  /// microsecond formatting artefacts when the value is read back.
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt':
        accessTokenExpiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    'refreshTokenExpiresAt':
        refreshTokenExpiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    'username': user.email,
    'provider': provider.name,
    'tokenType': tokenType,
  };

  // ── Display helpers ────────────────────────────────────────────────────────

  /// Remaining time until the access token expires.
  /// Returns [Duration.zero] if already expired.
  Duration get timeUntilExpiry {
    final remaining = accessTokenExpiresAt.toUtc().difference(
      DateTime.now().toUtc(),
    );
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Human-readable remaining time, e.g. "1h 58m" or "45s".
  String get expiresIn {
    final d = timeUntilExpiry;
    if (d == Duration.zero) return 'expired';
    if (d.inHours >= 1) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  /// Access-token expiry as a clean local-time string, e.g. "08 May 2026 16:51".
  ///
  /// Converts the stored UTC value to the device's local timezone so the
  /// displayed time matches what the user sees on their clock.
  String get formattedExpiresAt {
    final local = accessTokenExpiresAt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final mon = _monthAbbr(local.month);
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$d $mon ${local.year} $h:$m';
  }

  static String _monthAbbr(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];

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
      // JWT `exp` / `iat` claims are Unix timestamps in **seconds**.
      // Dart's DateTime.fromMillisecondsSinceEpoch expects milliseconds,
      // so multiply by 1000.
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
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
