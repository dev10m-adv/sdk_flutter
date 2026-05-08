import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/uids_sdk_config.dart';
import '../errors/uids_auth_exception.dart';
import '../models/auth_session.dart';
import '../models/device_models.dart';
import '../models/provider_auth_result.dart';
import 'auth_endpoints.dart';

/// HTTP client that communicates with the UIDS authentication backend.
///
/// All public methods convert HTTP / network errors into typed
/// [UidsAuthException] subclasses so callers never deal with raw Dio/http
/// exceptions.
final class AuthApiClient {
  AuthApiClient({
    required UidsSdkConfig config,
    http.Client? httpClient,
  })  : _config = config,
        _http = httpClient ?? http.Client(),
        _endpoints = AuthEndpoints(
          authBaseUrl: config.authBaseUrl,
          apiBaseUrl: config.apiBaseUrl,
        );

  final UidsSdkConfig _config;
  final http.Client _http;
  final AuthEndpoints _endpoints;

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Exchange a [ProviderAuthResult] for a backend [AuthSession].
  Future<AuthSession> exchangeProviderToken(ProviderAuthResult result) async {
    // final body = <String, dynamic>{
    //   'provider': result.provider.name,
    //   'id_token': result.idToken,
    //   'client_id': _config.clientId,
    //   if (_config.clientSecret != null) 'client_secret': _config.clientSecret,
    //   if (_config.audience != null) 'audience': _config.audience,
    //   if (result.accessToken != null)
    //     'provider_access_token': result.accessToken,
    //   if (result.serverAuthCode != null)
    //     'server_auth_code': result.serverAuthCode,
    // };
    final body = <String, dynamic>{
      'accessToken': result.accessToken,
      'idpName': result.provider.label,
      'tokenType': 'Bearer',
    };

    final json = await _post(_endpoints.exchangeToken, body, authToken: null);
    return AuthSession.fromJson(json);
  }

  /// Use [refreshToken] to obtain a refreshed [AuthSession].
  Future<AuthSession> refreshToken(String refreshToken) async {
    final body = <String, dynamic>{
      'refresh_token': refreshToken,
      'client_id': _config.clientId,
      if (_config.clientSecret != null) 'client_secret': _config.clientSecret,
    };

    try {
      final json = await _post(_endpoints.refreshToken, body, authToken: null);
      return AuthSession.fromJson(json);
    } on UidsNetworkException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 400) {
        throw const UidsRefreshTokenExpiredException();
      }
      rethrow;
    }
  }

  // ── Device ────────────────────────────────────────────────────────────────

  /// Register a new device; returns the [RegisteredDevice] from the backend.
  Future<RegisteredDevice> registerDevice(
    DeviceRegisterRequest request,
    String accessToken,
  ) async {
    final json = await _post(
      _endpoints.registerDevice,
      request.toJson(),
      authToken: accessToken,
    );
    return RegisteredDevice.fromJson(json);
  }

  /// Update an existing device.
  Future<RegisteredDevice> updateDevice(
    String deviceId,
    DeviceUpdateRequest request,
    String accessToken,
  ) async {
    final json = await _patch(
      _endpoints.updateDevice(deviceId),
      request.toJson(),
      authToken: accessToken,
    );
    return RegisteredDevice.fromJson(json);
  }

  /// Unregister (delete) a device.
  Future<void> unregisterDevice(String deviceId, String accessToken) async {
    await _delete(_endpoints.unregisterDevice(deviceId),
        authToken: accessToken);
  }

  /// Fetch and validate a registered device by ID.
  Future<RegisteredDevice> validateDevice(
    String deviceId,
    String accessToken,
  ) async {
    final json = await _get(
      _endpoints.validateDevice(deviceId),
      authToken: accessToken,
    );
    return RegisteredDevice.fromJson(json);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Map<String, String> _headers({String? authToken}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, dynamic> body, {
    required String? authToken,
  }) async {
    try {
      final response = await _http.post(
        uri,
        headers: _headers(authToken: authToken),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsNetworkException('POST $uri failed', cause: e);
    }
  }

  Future<Map<String, dynamic>> _patch(
    Uri uri,
    Map<String, dynamic> body, {
    required String? authToken,
  }) async {
    try {
      final response = await _http.patch(
        uri,
        headers: _headers(authToken: authToken),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsNetworkException('PATCH $uri failed', cause: e);
    }
  }

  Future<Map<String, dynamic>> _get(
    Uri uri, {
    required String? authToken,
  }) async {
    try {
      final response = await _http.get(
        uri,
        headers: _headers(authToken: authToken),
      );
      return _handleResponse(response);
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsNetworkException('GET $uri failed', cause: e);
    }
  }

  Future<void> _delete(Uri uri, {required String? authToken}) async {
    try {
      final response = await _http.delete(
        uri,
        headers: _headers(authToken: authToken),
      );
      if (response.statusCode >= 400) {
        throw UidsNetworkException(
          'DELETE $uri failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on UidsAuthException {
      rethrow;
    } catch (e) {
      throw UidsNetworkException('DELETE $uri failed', cause: e);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final message =
        'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';

    if (response.statusCode == 401) {
      throw UidsNetworkException(message, statusCode: response.statusCode);
    }

    throw UidsNetworkException(message, statusCode: response.statusCode);
  }
}
