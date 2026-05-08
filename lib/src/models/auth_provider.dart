/// Supported identity providers.
enum AuthProvider {
  google,
  microsoft;

  /// Human-readable label used in logs and error messages.
  String get label => switch (this) {
        AuthProvider.google => 'Gmail',
        AuthProvider.microsoft => 'Microsoft',
      };
}
