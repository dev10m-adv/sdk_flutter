/// Base exception for all UIDS Auth SDK errors.
sealed class UidsAuthException implements Exception {
  const UidsAuthException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Thrown when a network request fails (non-2xx, timeout, DNS, etc.).
final class UidsNetworkException extends UidsAuthException {
  const UidsNetworkException(
    super.message, {
    super.cause,
    this.statusCode,
  });

  final int? statusCode;
}

/// Thrown when the backend access token has expired and cannot be used.
final class UidsSessionExpiredException extends UidsAuthException {
  const UidsSessionExpiredException([super.message = 'Session has expired.']);
}

/// Thrown when the refresh token is invalid, revoked, or expired.
final class UidsRefreshTokenExpiredException extends UidsAuthException {
  const UidsRefreshTokenExpiredException(
      [super.message = 'Refresh token has expired or been revoked.']);
}

/// Thrown when the user cancels the provider sign-in flow.
final class UidsProviderCancelledException extends UidsAuthException {
  const UidsProviderCancelledException(
      [super.message = 'User cancelled the sign-in flow.']);
}

/// Thrown when a provider sign-in flow fails after it starts.
final class UidsProviderSignInException extends UidsAuthException {
  const UidsProviderSignInException(super.message, {super.cause});
}

/// Thrown when device registration or validation fails.
final class UidsDeviceRegistrationException extends UidsAuthException {
  const UidsDeviceRegistrationException(super.message, {super.cause});
}

/// Thrown when the SDK is used before [UidsAuthSdk.initialize] is called.
final class UidsNotInitializedException extends UidsAuthException {
  const UidsNotInitializedException(
      [super.message = 'SDK has not been initialized. Call initialize() first.']);
}

/// Thrown when a requested auth provider is not configured.
final class UidsProviderNotConfiguredException extends UidsAuthException {
  const UidsProviderNotConfiguredException(super.message);
}
