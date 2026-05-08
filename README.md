# UIDS Auth SDK for `uids_io_sdk_flutter`

This package now exposes the new UIDS authentication SDK implementation while
preserving the legacy package name `uids_io_sdk_flutter`.

## Features

- Provider sign-in for Google and Microsoft
- Backend token exchange and session management
- Silent provider refresh and session refresh
- Device registration as a separate flow
- Secure storage-backed persistence
- Zero bundled UI

## Package Identity

Use the old package name in your app dependency:

```yaml
dependencies:
  uids_io_sdk_flutter: ^0.2.0
```

Import either public barrel:

```dart
import 'package:uids_io_sdk_flutter/uids_io_sdk_flutter.dart';
```

or:

```dart
import 'package:uids_io_sdk_flutter/uids_auth_sdk.dart';
```

## Quick Start

```dart
import 'package:uids_io_sdk_flutter/uids_io_sdk_flutter.dart';

final sdk = UidsAuthSdk.create();

await sdk.initialize(
  UidsSdkConfig(
    apiBaseUrl: Uri.parse('https://api.example.com'),
    authBaseUrl: Uri.parse('https://auth.example.com'),
    clientId: 'backend-client-id',
    audience: 'api-audience',
    autoRefresh: true,
    refreshBeforeExpiry: Duration(minutes: 5),
    google: GoogleAuthConfig(
      webClientId: 'google-web-client-id',
      androidClientId: 'google-android-client-id',
      iosClientId: 'google-ios-client-id',
      desktopClientId: 'google-desktop-client-id',
      desktopRedirectUri: 'http://localhost/',
      useInstalledAppFlowOnDesktop: true,
    ),
    microsoft: MicrosoftAuthConfig(
      clientId: 'microsoft-client-id',
      tenantId: 'common',
    ),
  ),
);

final session = await sdk.signInWithProvider(
  provider: AuthProvider.google,
);

final device = await sdk.ensureDeviceRegistered(
  const DeviceRegisterRequest(
    stableDeviceKey: 'your-stable-uuid',
    platform: 'android',
  ),
);
```

## Architecture

The SDK separates authentication and device registration into two independent
flows. Signing in does not register a device, and signing out does not clear a
registered device unless you explicitly do so.

## Notes

- The previous bundled UI and legacy helper APIs are no longer part of the migrated SDK surface.
- The old package name is preserved so existing dependency coordinates do not need to change.
