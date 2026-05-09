import 'dart:convert';

/// Decodes a JWT payload and returns its claims map.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) {
    throw const FormatException('Invalid JWT format');
  }

  final payloadPart = parts[1];
  final normalized = base64Url.normalize(payloadPart);
  final decoded = utf8.decode(base64Url.decode(normalized));
  final payload = jsonDecode(decoded);

  if (payload is Map<String, dynamic>) {
    return payload;
  }
  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }

  throw const FormatException('Invalid JWT payload');
}

/// Returns JWT `exp` as UTC DateTime.
DateTime readJwtExpiry(String token) {
  final payload = decodeJwtPayload(token);
  final exp = payload['exp'];

  if (exp is num) {
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  }

  if (exp is String) {
    final parsed = int.tryParse(exp);
    if (parsed != null) {
      return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
    }
  }

  throw const FormatException('JWT is missing a valid exp claim');
}
