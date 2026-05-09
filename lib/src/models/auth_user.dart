/// Represents an authenticated user returned from the backend.
final class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.metadata = const {},
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final Map<String, dynamic> metadata;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      );

  factory AuthUser.temp(String email) => AuthUser(
        id: email,
        email: email,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  @override
  String toString() => 'AuthUser(id: $id, email: $email)';
}
