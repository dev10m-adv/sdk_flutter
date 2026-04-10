# uids_io_sdk_flutter

Flutter package for integrating **single sign-on (SSO)** with your auth backend: email/password, OTP, device registration, Google (Gmail) sign-in, token refresh, and optional UI widgets. 

Targets **Web**, **Android**, **iOS**, and **desktop** (Linux, macOS, Windows).

## Features

- **Configuration** – Point the SDK at your auth service via `Configuration.AuthUrl` and `AudDomain`.
- **Device registration** – `RegisterService` registers the device and stores returned configuration (including IdP settings).
- **Email auth** – Login, registration, and OTP verification (`auth.dart`) against your API.
- **Google sign-in** – `GmailSSO` for Google OAuth; uses platform-appropriate flows (including GIS on web).
- **Tokens** – JWT and refresh handling with `RefreshTokenService` and secure storage.
- **Optional UI** – `AuthScreen`, `AuthButtons`, and `AuthLogout` for a quick integration with `go_router`.
- **Stable response models** – `lib/models/sdk_outputs.dart` defines fixed Dart shapes (`AuthEntitiesResponse`, `TenantBinding`, `AudTokenResponse`, `RefreshTokenResponse`, `DeviceRegistrationResponse`) with `fromJson` that accepts both AdvComm AuthAPI wire keys (`Token`, `refresh_token`, …) and normalized `toJson` for storage. Import from `package:uids_io_sdk_flutter/models/sdk_outputs.dart` or the package barrel (`uids_io_sdk_flutter.dart`). Legacy types (`AuthResponseModel`, `Entity`, `AuthTokenModel`) remain and delegate to these DTOs where applicable.

## Requirements

| Requirement | Version |
|-------------|---------|
| Dart        | `^3.9.0` |
| Flutter     | `>=3.35.0` |

## Installation

Add the dependency to your app’s `pubspec.yaml`:

```yaml
dependencies:
  uids_io_sdk_flutter: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick start

### 1. Configure endpoints

Before calling any API, set your auth base URL (and optional AUD domain):

```dart
import 'package:uids_io_sdk_flutter/configuration.dart';

void setupAuth() {
  Configuration.AuthUrl = 'https://your-auth.example.com';
  Configuration.AudDomain = 'https://your-auth.example.com';
}
```

### 2. Register the device

Call device registration early (for example after your app starts) so `DeviceId` and IdP **Configurations** are stored for SSO:

```dart
import 'package:uids_io_sdk_flutter/services/register_service.dart';

// e.g. in main() after WidgetsFlutterBinding.ensureInitialized()
await RegisterService.registerDeviceData();
```

### 3. Use the bundled auth UI (optional)

The package exports `AuthScreen` and related widgets. Wire your app with a router (the SDK uses `go_router` for navigation after login):

```dart
import 'package:uids_io_sdk_flutter/auth_view.dart';

// Example: use AuthScreen as your sign-in route widget
AuthScreen(key: globalKey); // see package example/
```

### 4. Or integrate programmatically

Import the barrel file for the public API:

```dart
import 'package:uids_io_sdk_flutter/uids_io_sdk_flutter.dart';
```

Use `loginWithCredentials`, `registerUser`, `GmailSSO`, `RefreshTokenService`, `AuthLogout`, etc., according to your flow.

## Platform notes

- **Web / Google sign-in** – Recent `google_sign_in` versions use the Google Identity Services (GIS) button on web. The SDK shows a dialog with the official sign-in button when the user starts Google SSO; ensure your OAuth client and redirect URIs match your [Google Cloud Console](https://console.cloud.google.com/) setup.
- **Desktop / Google** – Linux, macOS, and Windows use an embedded OAuth flow (`flutter_inappwebview`) toward your configured redirect URI.
- **Host header** – Your auth server may resolve tenant/app config from the request `Host`. When testing locally, keep the host consistent with what your backend expects.

## Exports

The main library is `uids_io_sdk_flutter.dart`. It re-exports services, models, auth helpers, `Configuration`, and `gmail_sso.dart`. Import it once:

```dart
import 'package:uids_io_sdk_flutter/uids_io_sdk_flutter.dart';
```

## Example

See the [`example/`](example/) folder for a minimal app that uses `AuthScreen`.

## Links

- **Repository:** [github.com/uids-io/sdk_flutter](https://github.com/uids-io/sdk_flutter)
- **Changelog:** [`CHANGELOG.md`](CHANGELOG.md)

## License

See [LICENSE](LICENSE).
