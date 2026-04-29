## 0.2.0

* **Breaking (wire JSON):** Aligned with AdvComm AuthAPI **camelCase** only (no PascalCase/snake aliases in SDK parsers).

  **Requests**

  | Endpoint | Changed |
  |----------|---------|
  | `POST /auth` | `AzureTokenInputModel` sends `accessToken`, `idpName`, `tokenType`. |
  | `POST /aud` | `AudModel` sends `username`, `tenant`, `refreshToken`, `deviceId`, `idpName`. |
  | `POST /refresh` | Body uses `refreshToken`, `username`. |

  **Responses**

  - `TenantBinding`: `tenant`, **`refreshToken`**, **`authorizations.roles`** (no `refresh_token` / `refreshtoken`).
  - `AuthEntitiesResponse`: **`entities`**, `username`, `idpName`, `errorDetails` (no `Entities`/`Username`/… mixes).
  - `AudTokenResponse` / `/refresh`: JWT in **`token`**, refresh in **`refreshToken`**; optional **`isSuccess`** on `/aud`.
  - `DeviceRegistrationResponse`: **`isSuccess`**, **`deviceId`**, **`audDomain`**, **`configurations`**.

  If persisted DB rows emit snake_case, normalize JSON in AuthAPI **before** `res.json`; the SDK expects camelCase UID objects.

* **Logging:** Replaced `print` / `debugPrint` with `dart:developer` logging via `lib/src/sdk_log.dart`. Namespaces are `uids_io_sdk_flutter.<auth|gmail|token|device>`. Debug-only traces use `sdkLogDebug` / `sdkLogInfo` (suppressed in release). Failures use `sdkLogWarning` / `sdkLogError`. Dio HTTP failures log `dioErrorSummary` (method, URL, status, type) — **not** request/response bodies, to avoid leaking tokens.

## 0.1.0

* **Breaking:** Google Sign-In updated to v7 (`google_sign_in` ^7.2.0). Web sign-in now uses the GIS `renderButton` flow (dialog with Google button) because `authenticate()` is not supported on web.
* **Breaking:** Minimum SDK `^3.9.0`, Flutter `>=3.35.0` (required by `google_sign_in_web`).
* Upgraded `flutter_secure_storage` ^10, `go_router` ^17, `device_info_plus` ^12, `flutter_lints` ^6.
* Added direct dependency on `google_sign_in_web` for the web-only sign-in implementation.
* Replaced deprecated `DioError` / `onLoadError` usage in `gmail_sso.dart` with `DioException` / `onReceivedError`.

## 0.0.1

* TODO: Describe initial release.
