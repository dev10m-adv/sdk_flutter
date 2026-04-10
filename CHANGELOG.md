## 0.2.0

* Added `lib/models/sdk_outputs.dart`: canonical response DTOs `TenantBinding`, `AuthEntitiesResponse`, `AudTokenResponse`, `RefreshTokenResponse`, `DeviceRegistrationResponse` (Dart `lowerCamelCase` fields; parsers accept snake_case / PascalCase from the server).
* `AuthResponseModel` now builds on `AuthEntitiesResponse` and exposes `asCanonical`; `Entity` wraps `TenantBinding` for backward compatibility (`Authorization` / `authorizations` unchanged).
* `AuthTokenModel.fromJson` delegates to `AudTokenResponse`; added `asAudTokenResponse`.
* `RegisterService` / `RefreshTokenService` parse responses with `DeviceRegistrationResponse` / `RefreshTokenResponse`.
* `AudModel` uses `idpName` instead of `idpname_backend` in the constructor (deprecated getter kept).
* Package barrel exports `sdk_outputs.dart`.

## 0.1.0

* **Breaking:** Google Sign-In updated to v7 (`google_sign_in` ^7.2.0). Web sign-in now uses the GIS `renderButton` flow (dialog with Google button) because `authenticate()` is not supported on web.
* **Breaking:** Minimum SDK `^3.9.0`, Flutter `>=3.35.0` (required by `google_sign_in_web`).
* Upgraded `flutter_secure_storage` ^10, `go_router` ^17, `device_info_plus` ^12, `flutter_lints` ^6.
* Added direct dependency on `google_sign_in_web` for the web-only sign-in implementation.
* Replaced deprecated `DioError` / `onLoadError` usage in `gmail_sso.dart` with `DioException` / `onReceivedError`.

## 0.0.1

* TODO: Describe initial release.
